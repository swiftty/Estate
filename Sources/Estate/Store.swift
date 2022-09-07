import Foundation
import OSLog

public typealias StoreOf<C: Composable> = Store<C.State, C.Action>

@MainActor
public final class Store<
    State: Sendable,
    Action: Sendable
>: ObservableObject, Sendable {
    public var state: State {
        #if DEBUG
        if isReplaying, let replayState = replayState {
            return replayState
        }
        #endif
        proceedStableIndexIfPossible()
        var state = stableState
        for event in events[stableIndex...] {
            event.apply(&state)
        }
        return state
    }

    public let initialState: State

    var events: [Event] = []
    private(set) var stableIndex = 0
    private(set) var stableState: State

    private var tasks: [Effect<Mutation<State>>.ID?: [Task<Void, Error>]] = [:]
    #if DEBUG
    public private(set) var isReplaying = false {
        willSet { objectWillChange.send() }
    }
    private var replayState: State? {
        willSet { objectWillChange.send() }
    }
    #endif

    private let composer: any Composable<State, Action>
    private let logger: Logger

    public init<Composer: Composable>(initialState state: State, composer: Composer, logger: Logger = .init(.disabled))
    where State == Composer.State, Action == Composer.Action {
        self.initialState = state
        self.stableState = initialState
        self.composer = composer
        self.logger = logger
    }

    deinit {
        logger.debug("\(type(of: self)) deinit")
        tasks.values.lazy.flatMap { $0 }.forEach { $0.cancel() }
    }

    @discardableResult
    public func send(_ newAction: Action) -> Task<Void, Error> {
        #if DEBUG
        if isReplaying {
            return Task {}
        }
        #endif
        let effect = composer.mutate(state: state, action: newAction)
        logger.debug("send \(String(describing: newAction))")
        let context = Effect<Mutation<State>>.Yield.Context(
            snapshotID: effect.id,
            snapshotTasks: tasks,
            actionSender: { [weak self] action in
                let sender = self?.send as (@MainActor (Action) -> Task<Void, Error>)?
                return Task { @MainActor in
                    try await sender?(action as! Action).value
                }
            }
        )
        guard let mutations = effect.run(with: context) else {
            return Task {}
        }
        let task = Task {
            var modifiedIndex: [Int] = []
            do {
                for try await (mutation, stable) in mutations {
                    try Task.checkCancellation()
                    objectWillChange.send()
                    if !stable {
                        modifiedIndex.append(events.endIndex)
                    }
                    let id = Event.ID(events.endIndex)
                    events.append(.init(id: id, status: stable ? .stable : .unstable, mutation: mutation))
                    logger.debug("recieve event [\(String(describing: id))] on \(String(describing: newAction))")
                }
                try Task.checkCancellation()
                for index in modifiedIndex {
                    events[index].status = .stable
                }
            } catch {
                if !modifiedIndex.isEmpty, effect.revert(error) {
                    objectWillChange.send()
                    for index in modifiedIndex {
                        events[index].status = .invalid
                    }
                    throw error
                } else {
                    for index in modifiedIndex {
                        events[index].status = .stable
                    }
                    throw error
                }
            }
        }
        tasks[effect.id, default: []].append(task)
        // clean up
        Task {
            do {
                try await task.value
                logger.debug("task finished on \(String(describing: newAction))")
            } catch is CancellationError {
                logger.debug("task cancelled on \(String(describing: newAction))")
            } catch {
                logger.debug("task error on \(String(describing: newAction)), reason: \(String(describing: error), privacy: .private)")
            }
            tasks[effect.id]?.removeAll(where: { $0 == task })
        }
        return task
    }

    func proceedStableIndexIfPossible() {
        let currentIndex = stableIndex
        let events = events[currentIndex...]
        stableIndex = events.firstIndex(where: { $0.status == .unstable }) ?? events.endIndex
        if stableIndex != currentIndex {
            var state = stableState
            for event in events[..<stableIndex] {
                event.apply(&state)
            }
            stableState = state
        }
    }

    func waitForAllTasks() async {
        await tasks.values.flatMap { $0 }.waitForAll()
    }
}

extension Store {
    @discardableResult
    public func send(_ actions: [Action]) -> Task<Void, Error> {
        Task {
            let errors = await withTaskGroup(of: Result<Void, Error>.self, returning: [Error].self) { group in
                for action in actions {
                    let task = send(action)
                    group.addTask {
                        await task.result
                    }
                }
                var errors: [Error] = []
                for await case .failure(let error) in group {
                    errors.append(error)
                }
                return errors
            }
            if let error = errors.first {
                throw error
            }
        }
    }

    @discardableResult
    @_disfavoredOverload
    public func send(_ actions: Action...) -> Task<Void, Error> {
        send(actions)
    }
}

#if DEBUG
extension Store {
    public func replay(duration milliseconds: UInt64) async {
        await waitForAllTasks()
        assert(tasks.values.flatMap { $0 }.isEmpty)
        await Task.yield()
        isReplaying = true
        defer {
            isReplaying = false
            replayState = nil
        }
        do {
            let initial: (inout State) -> Bool = { _ in true }
            let seq = events.map { e in { e.apply(&$0) } }

            var state = initialState
            for apply in [initial] + seq where apply(&state) {
                replayState = state
                try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
                await Task.yield()
            }
        } catch {}
    }
}
#endif

// MARK: - private
extension Store {
    struct Event: Identifiable, Sendable {
        enum Status {
            case unstable, stable, invalid
        }
        let id: ID
        var status: Status
        private let mutation: @Sendable (inout State) -> Void

        init(id: ID, status: Status = .unstable, mutation: @escaping @Sendable (inout State) -> Void) {
            self.id = id
            self.status = status
            self.mutation = mutation
        }

        @discardableResult
        func apply(_ state: inout State) -> Bool {
            guard status != .invalid else { return false }
            mutation(&state)
            return true
        }
    }
}

extension Store.Event {
    struct ID: Hashable, CustomStringConvertible, Sendable {
        let content: AnyHashable

        var description: String { "ID(\(String(describing: content.base)))" }

        public init<H: Hashable>(_ raw: H) {
            content = raw
        }
    }
}

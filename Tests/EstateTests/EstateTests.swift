import XCTest
@testable import Estate

class EstateTests: XCTestCase {
    @MainActor
    func test_store() async throws {
        struct State {
            var count = 0
        }
        enum Action {
            case incr
        }
        struct Composer: Composable {
            func mutate(state: State, action: Action) -> Effect<Mutation<State>> {
                switch action {
                case .incr:
                    return Effect.just {
                        $0.count += 1
                    }
                }
            }
        }

        let store = Store<_, Action>(initialState: State(), composer: Composer())

        XCTAssertEqual(store.state.count, 0)

        try await store.send(.incr).value

        XCTAssertEqual(store.state.count, 1)
    }

    @MainActor
    func test_store_cancel_prev_action() async throws {
        struct State {
            var count = 0
        }
        enum Action {
            case incr(Int)
        }
        struct Composer: Composable {
            func mutate(state: State, action: Action) -> Effect<Mutation<State>> {
                switch action {
                case .incr(let val):
                    struct Key: Hashable {}
                    return Effect(id: Key()) { yield in
                        yield {
                            $0.count += 1 * val
                        }
                        yield {
                            $0.count += 1 * val
                        }
                        for task in yield.context.tasks {
                            task.cancel()
                        }
                    }
                }
            }
        }

        let store = Store<_, Action>(initialState: State(), composer: Composer())

        async let task1: Void = try await store.send(.incr(1)).value
        async let task2: Void = try await store.send(.incr(10)).value

        XCTAssertEqual(store.state.count, 0)

        do {
            try await task1
            try await task2
            XCTFail()
        } catch {
            XCTAssertTrue(error is CancellationError)
        }

        XCTAssertEqual(store.state.count, 20)
    }
}

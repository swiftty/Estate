import XCTest
@testable import Estate

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

class MassiveStateTests: XCTestCase {
    @MainActor
    func test_state_with_massive_events__1_000() async throws {
        let store = Store<_, Action>(initialState: State(), composer: Composer())

        let total = 1000

        store.events = .init(repeating: .init(id: .init(1), status: .stable, mutation: { $0.count += 1 }), count: total)
        XCTAssertEqual(store.stableIndex, 0)
        _ = store.state
        store.events.append(.init(id: .init(2), status: .unstable, mutation: { $0.count += 1 }))

        XCTAssertEqual(store.stableIndex, total)

        measure {
            _ = store.state
        }

        XCTAssertEqual(store.stableIndex, total)
        XCTAssertEqual(store.state.count, total + 1)
    }

    @MainActor
    func test_state_with_massive_events__10_000() async throws {
        let store = Store<_, Action>(initialState: State(), composer: Composer())

        let total = 10_000

        store.events = .init(repeating: .init(id: .init(1), status: .stable, mutation: { $0.count += 1 }), count: total)
        XCTAssertEqual(store.stableIndex, 0)
        _ = store.state
        store.events.append(.init(id: .init(2), status: .unstable, mutation: { $0.count += 1 }))

        XCTAssertEqual(store.stableIndex, total)

        measure {
            _ = store.state
        }

        XCTAssertEqual(store.stableIndex, total)
        XCTAssertEqual(store.state.count, total + 1)
    }

    @MainActor
    func test_state_with_massive_events__100_000() async throws {
        let store = Store<_, Action>(initialState: State(), composer: Composer())

        let total = 100_000

        store.events = .init(repeating: .init(id: .init(1), status: .stable, mutation: { $0.count += 1 }), count: total)
        XCTAssertEqual(store.stableIndex, 0)
        _ = store.state
        store.events.append(.init(id: .init(2), status: .unstable, mutation: { $0.count += 1 }))

        XCTAssertEqual(store.stableIndex, total)

        measure {
            _ = store.state
        }

        XCTAssertEqual(store.stableIndex, total)
        XCTAssertEqual(store.state.count, total + 1)
    }

    @MainActor
    func test_state_with_massive_events__10_000_000() async throws {
        let store = Store<_, Action>(initialState: State(), composer: Composer())

        let total = 10_000_000

        store.events = .init(repeating: .init(id: .init(1), status: .stable, mutation: { $0.count += 1 }), count: total)
        XCTAssertEqual(store.stableIndex, 0)
        _ = store.state
        store.events.append(.init(id: .init(2), status: .unstable, mutation: { $0.count += 1 }))

        XCTAssertEqual(store.stableIndex, total)

        measure {
            _ = store.state
        }

        XCTAssertEqual(store.stableIndex, total)
        XCTAssertEqual(store.state.count, total + 1)
    }
}

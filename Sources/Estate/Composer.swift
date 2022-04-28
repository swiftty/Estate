import Foundation

public typealias Mutation<State> = @Sendable (inout State) -> Void

public protocol Composable {
    associatedtype State
    associatedtype Action

    @Sendable
    func mutate(state: State, action: Action) -> Effect<Mutation<State>>
}

// MARK: -
struct AnyComposer<State, Action>: Composable, Sendable {
    let mutator: @Sendable (State, Action) -> Effect<Mutation<State>>

    init<Composer: Composable>(_ composer: Composer)
    where State == Composer.State, Action == Composer.Action {
        mutator = composer.mutate(state:action:)
    }

    func mutate(state: State, action: Action) -> Effect<Mutation<State>> {
        mutator(state, action)
    }
}

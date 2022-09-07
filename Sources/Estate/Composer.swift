import Foundation

public typealias Mutation<State> = @Sendable (inout State) -> Void

public protocol Composable<State, Action> {
    associatedtype State
    associatedtype Action

    @Sendable
    func mutate(state: State, action: Action) -> Effect<Mutation<State>>
}

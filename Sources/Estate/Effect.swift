import Foundation

public struct Effect<Value>: Sendable where Value: Sendable {
    // MARK: - public
    public struct ID: Hashable, Sendable {
        let content: AnyHashable

        public init<H: Hashable>(_ raw: H) {
            content = raw
        }
    }
    public struct Yield: Sendable {
        public struct Context: Sendable {
            public let tasks: [Task<Void, Error>]
        }
        public let context: Context

        let runner: @Sendable (Value, Bool) -> Void

        public func callAsFunction(stable: Bool = false, _ value: Value) {
            runner(value, stable)
        }
    }
    public let id: ID?

    // MARK: -
    let revert: @Sendable (Error) -> Bool

    // MARK: -
    private enum Kind {
        case none
        case executor(@Sendable (Yield.Context, @Sendable (Continuation) -> Void) async throws -> Void)
    }
    private enum Continuation {
        case value(Value, Bool)
        case finish
    }
    private let kind: Kind

    private init(_id id: ID?, revert: (@Sendable (Error) -> Bool)?, kind: Kind) {
        self.id = id
        self.revert = revert ?? { $0 is CancellationError }
        self.kind = kind
    }

    private init(_id id: ID?,
                 revert: (@Sendable (Error) -> Bool)?,
                 runner: @escaping @Sendable (Yield.Context, @Sendable (Continuation) -> Void) async throws -> Void) {
        self.init(_id: id, revert: revert, kind: .executor(runner))
    }

    func run(with context: Yield.Context) -> AsyncThrowingStream<(Value, Bool), Error>? {
        guard case .executor(let runner) = kind else { return nil }
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await runner(context) { cont in
                        switch cont {
                        case .value(let value, let stable):
                            continuation.yield((value, stable))

                        case .finish:
                            continuation.finish()
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

extension Effect {
    public init(id: ID? = nil,
                revert: (@Sendable (Error) -> Bool)? = nil,
                runner: @escaping @Sendable (Yield) async throws -> Void) {
        self.init(_id: id, revert: revert) { context, notify in
            try await withoutActuallyEscaping(notify) { notify in
                try await runner(.init(context: context) {
                    notify(.value($0, $1))
                })
                notify(.finish)
            }
        }
    }
}

extension Effect {
    public static func value(id: ID? = nil, _ value: @escaping @Sendable (Yield.Context) async throws -> Value) -> Self {
        self.init(_id: id, revert: nil) { context, notify in
            notify(.value(try await value(context), false))
            notify(.finish)
        }
    }

    public static func just(id: ID? = nil, _ value: @escaping @autoclosure @Sendable () -> Value) -> Self {
        .value(id: id) { _ in
            value()
        }
    }
}

extension Effect: ExpressibleByNilLiteral {
    public static var none: Self {
        self.init(_id: nil, revert: nil, kind: .none)
    }

    public init(nilLiteral: ()) {
        self = .none
    }
}

@preconcurrency import SwiftUI

#if DEBUG

@propertyWrapper
public struct OverridableEnvironment<Value>: DynamicProperty {
    public var wrappedValue: Value {
        get { overrideValue ?? environment.wrappedValue }
        set { overrideValue = newValue }
    }

    private var environment: Environment<Value>
    @State private var overrideValue: Value?

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        environment = Environment(keyPath)
    }

    public init(wrappedValue: Value, _ keyPath: KeyPath<EnvironmentValues, Value>) {
        environment = Environment(keyPath)
        _overrideValue = State(initialValue: wrappedValue)
    }

    public mutating func reset() {
        overrideValue = nil
    }
}

extension OverridableEnvironment: Sendable where Value: Sendable {}

#else

public typealias OverridableEnvironment = Environment

#endif

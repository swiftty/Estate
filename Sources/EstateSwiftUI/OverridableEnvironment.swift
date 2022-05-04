@preconcurrency import SwiftUI

#if DEBUG

@propertyWrapper
public struct OverridableEnvironment<Value>: DynamicProperty {
    public var wrappedValue: Value {
        get { stateOverrideValue ?? overrideValue ?? environment.wrappedValue }
        set {
            overrideValue = newValue
            stateOverrideValue = newValue
        }
    }

    private var environment: Environment<Value>
    private var overrideValue: Value?
    @State private var stateOverrideValue: Value?

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        environment = Environment(keyPath)
    }

    public mutating func reset() {
        overrideValue = nil
        stateOverrideValue = nil
    }
}

extension OverridableEnvironment: Sendable where Value: Sendable {}

#else

public typealias OverridableEnvironment = Environment

#endif

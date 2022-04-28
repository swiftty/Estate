import SwiftUI
import Combine

@propertyWrapper
public struct LazyStateObject<ObjectType, Dependency>: DynamicProperty
where ObjectType: ObservableObject {
    @MainActor
    public var wrappedValue: ObjectType {
        if let object = holder.object {
            return object
        }
        let newObject = initializer(dependency)
        holder.object = newObject
        return newObject
    }

    @StateObject private var holder = ObjectHolder<ObjectType>()

    private let dependency: Dependency
    private let initializer: (Dependency) -> ObjectType

    public init(dependency: Dependency, _ initializer: @escaping (Dependency) -> ObjectType) {
        self.dependency = dependency
        self.initializer = initializer
    }
}

private final class ObjectHolder<ObjectType>: ObservableObject
where ObjectType: ObservableObject {
    var object: ObjectType? {
        willSet {
            cancellable = newValue?.objectWillChange
                .sink(receiveValue: { [weak self] _ in
                    self?.objectWillChange.send()
                })
            objectWillChange.send()
        }
    }

    let objectWillChange = ObservableObjectPublisher()
    private var cancellable: Cancellable? {
        willSet { cancellable?.cancel() }
    }
}

import Estate
import SwiftUI

extension Store {
    @MainActor
    @dynamicMemberLookup
    public struct Binder: Sendable {
        public subscript <Value>(
            dynamicMember keyPath: KeyPath<State, Value>
        ) -> (@escaping (Value) -> Action) -> Binding<Value> {
            return { transform in
                Binding(
                    get: {
                        store.state[keyPath: keyPath]
                    },
                    set: { newValue in
                        store.send(transform(newValue))
                    }
                )
            }
        }

        let store: Store
    }

    public var binding: Binder { Binder(store: self) }
}

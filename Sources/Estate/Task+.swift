import Foundation

extension Collection where Element == Task<Void, Error> {
    public func waitForAll() async throws {
        guard !isEmpty else { return }
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for task in self {
                    group.addTask {
                        try await task.value
                    }
                }
                try await group.waitForAll()
            }
        } catch is CancellationError {
            // no throw when cancelled
        }
    }
}

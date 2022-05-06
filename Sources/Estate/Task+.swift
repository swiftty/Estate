import Foundation

extension Collection where Element == Task<Void, Error> {
    public func waitForAll() async {
        guard !isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            for task in self {
                group.addTask {
                    _ = await task.result
                }
            }
            await group.waitForAll()
        }
    }
}

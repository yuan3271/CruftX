import Foundation

/// Moves items to the Trash instead of deleting them, so cleanup is
/// recoverable. Reports what was freed and what failed.
enum Cleaner {
    static func clean(_ items: [JunkItem]) -> CleanSummary {
        var freed: Int64 = 0
        var cleanedCount = 0
        var failed: [String] = []
        let fm = FileManager.default

        for item in items {
            do {
                var resultingURL: NSURL?
                try fm.trashItem(at: item.path, resultingItemURL: &resultingURL)
                freed += item.sizeBytes
                cleanedCount += 1
            } catch {
                failed.append(item.name)
            }
        }

        return CleanSummary(freedBytes: freed, itemCount: cleanedCount, failedPaths: failed)
    }
}

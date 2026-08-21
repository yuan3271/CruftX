import Foundation

/// Moves items to the Trash (or the app-managed Recycle Bin) so cleanup is
/// recoverable. Reports what was freed and what failed.
enum Cleaner {
    static func clean(_ items: [JunkItem], destination: String = "trash") -> CleanSummary {
        if destination == "recycle" {
            return RecycleBin.move(items)
        }

        var freed: Int64 = 0
        var cleanedCount = 0
        var failed: [String] = []
        var permissionFailures = 0
        let fm = FileManager.default

        for item in items {
            do {
                var resultingURL: NSURL?
                try fm.trashItem(at: item.path, resultingItemURL: &resultingURL)
                freed += item.sizeBytes
                cleanedCount += 1
            } catch {
                failed.append(item.name)
                if Permissions.isPermissionError(error) { permissionFailures += 1 }
            }
        }

        return CleanSummary(
            freedBytes: freed,
            itemCount: cleanedCount,
            failedPaths: failed,
            permissionFailures: permissionFailures
        )
    }
}

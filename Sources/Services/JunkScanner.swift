import Foundation

/// Scans user-level locations for everyday junk: caches, logs, diagnostics,
/// Xcode derived data and temporary files. Everything is grouped by kind.
enum JunkScanner {

    static func scanDailyJunk(kinds: Set<JunkKind>) -> [ScannedEntry] {
        var entries: [ScannedEntry] = []
        let home = FileManager.default.homeDirectoryForCurrentUser

        if kinds.contains(.caches) {
            let caches = home.appendingPathComponent("Library/Caches", isDirectory: true)
            entries += topLevelItems(in: caches, kind: .caches, excludePrefixes: [])
        }

        if kinds.contains(.logs) {
            let logs = home.appendingPathComponent("Library/Logs", isDirectory: true)
            entries += topLevelItems(in: logs, kind: .logs, excludePrefixes: [], excludeNames: ["DiagnosticReports"])
        }

        if kinds.contains(.diagnosticReports) {
            let diag = home.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
            entries += topLevelItems(in: diag, kind: .diagnosticReports, excludePrefixes: [])
        }

        if kinds.contains(.derivedData) {
            let dd = home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
            entries += topLevelItems(in: dd, kind: .derivedData, excludePrefixes: [])
        }

        if kinds.contains(.tempFiles) {
            entries += tempItems(in: URL(fileURLWithPath: "/tmp", isDirectory: true))
            entries += tempItems(in: URL(fileURLWithPath: "/private/var/tmp", isDirectory: true))
        }

        return entries
    }

    // MARK: - Helpers

    private static func topLevelItems(
        in directory: URL,
        kind: JunkKind,
        excludePrefixes: [String],
        excludeNames: [String] = []
    ) -> [ScannedEntry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { url -> ScannedEntry? in
            let name = url.lastPathComponent
            guard !name.hasPrefix(".") else { return nil }
            guard !excludeNames.contains(name) else { return nil }
            guard !excludePrefixes.contains(where: { name.hasPrefix($0) }) else { return nil }

            guard let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
            ) else { return nil }
            if values.isSymbolicLink == true { return nil }

            let size: Int64
            if values.isDirectory == true {
                size = directorySize(at: url)
            } else {
                size = Int64(values.fileSize ?? 0)
            }
            guard size > 0 else { return nil }

            return ScannedEntry(
                name: name,
                path: url,
                sizeBytes: size,
                kind: kind,
                residueKind: nil,
                appName: nil
            )
        }
    }

    private static func tempItems(in directory: URL) -> [ScannedEntry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let currentUID = getuid()
        return urls.compactMap { url -> ScannedEntry? in
            guard let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
            ) else { return nil }
            if values.isSymbolicLink == true { return nil }
            // Only touch files owned by the current user in shared temp directories.
            if let owner = ownerID(of: url), owner != currentUID { return nil }

            let size: Int64
            if values.isDirectory == true {
                size = directorySize(at: url)
            } else {
                size = Int64(values.fileSize ?? 0)
            }
            guard size > 0 else { return nil }

            return ScannedEntry(
                name: url.lastPathComponent,
                path: url,
                sizeBytes: size,
                kind: .tempFiles,
                residueKind: nil,
                appName: nil
            )
        }
    }

    /// Recursively sums the size of regular files under a directory.
    static func directorySize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) else {
            return 0
        }

        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let values = try fileURL.resourceValues(forKeys: keys)
                if values.isSymbolicLink == true { continue }
                if values.isRegularFile == true {
                    total += Int64(values.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        return total
    }

    private static func ownerID(of url: URL) -> Int? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.ownerAccountID] as? Int
    }
}

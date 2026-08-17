import Foundation

/// App-managed cleanup destination. Files moved here can be restored to
/// their original location or permanently deleted by the user.
enum RecycleBin {
    struct Entry: Codable, Identifiable, Sendable {
        let id: String
        let name: String
        let originalPath: String
        let storedPath: String
        let sizeBytes: Int64
        let movedAt: Date
    }

    private static let directoryName = "RecycleBin"
    private static let manifestName = "manifest.json"

    static var rootURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CruftX/\(directoryName)", isDirectory: true)
    }

    private static var manifestURL: URL {
        rootURL.appendingPathComponent(manifestName)
    }

    // MARK: - Moving items in

    static func move(_ items: [JunkItem]) -> CleanSummary {
        let fm = FileManager.default
        try? fm.createDirectory(at: rootURL, withIntermediateDirectories: true)

        var entries = loadEntries()
        var freed: Int64 = 0
        var movedCount = 0
        var failed: [String] = []

        for item in items {
            let id = UUID().uuidString
            let storedDir = rootURL.appendingPathComponent(id, isDirectory: true)
            do {
                try fm.createDirectory(at: storedDir, withIntermediateDirectories: true)
                try fm.moveItem(at: item.path, to: storedDir.appendingPathComponent(item.path.lastPathComponent))
                entries.append(Entry(
                    id: id,
                    name: item.path.lastPathComponent,
                    originalPath: item.path.path,
                    storedPath: storedDir.appendingPathComponent(item.path.lastPathComponent).path,
                    sizeBytes: item.sizeBytes,
                    movedAt: Date()
                ))
                freed += item.sizeBytes
                movedCount += 1
            } catch {
                failed.append(item.name)
            }
        }

        save(entries)
        return CleanSummary(freedBytes: freed, itemCount: movedCount, failedPaths: failed)
    }

    // MARK: - Listing and restoring

    static func entries() -> [Entry] {
        loadEntries().sorted { $0.movedAt > $1.movedAt }
    }

    static func restore(_ entry: Entry) -> Bool {
        let fm = FileManager.default
        let originalURL = URL(fileURLWithPath: entry.originalPath)
        do {
            try fm.createDirectory(
                at: originalURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fm.moveItem(at: URL(fileURLWithPath: entry.storedPath), to: originalURL)
            var entries = loadEntries()
            entries.removeAll { $0.id == entry.id }
            save(entries)
            return true
        } catch {
            return false
        }
    }

    static func delete(_ entry: Entry) -> Bool {
        let fm = FileManager.default
        do {
            try fm.removeItem(at: URL(fileURLWithPath: entry.storedPath))
            try? fm.removeItem(at: URL(fileURLWithPath: entry.storedPath).deletingLastPathComponent())
            var entries = loadEntries()
            entries.removeAll { $0.id == entry.id }
            save(entries)
            return true
        } catch {
            return false
        }
    }

    static func emptyAll() -> Int {
        let entries = loadEntries()
        for entry in entries {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: entry.storedPath))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: entry.storedPath).deletingLastPathComponent())
        }
        try? FileManager.default.removeItem(at: manifestURL)
        return entries.count
    }

    // MARK: - Manifest persistence

    private static func loadEntries() -> [Entry] {
        guard let data = try? Data(contentsOf: manifestURL) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private static func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }
}

import Foundation

/// Persists "ignored" uninstall-residue items. Temporary ignores expire
/// automatically; permanent ones stay until the user removes them.
enum IgnoreManager {
    enum Kind: String, Codable {
        case temporary
        case permanent
    }

    struct Entry: Codable, Identifiable, Sendable {
        let path: String
        let kind: Kind
        let until: Date?

        var id: String { path }
    }

    enum Status: Equatable {
        case none
        case temporary(until: Date)
        case permanent
    }

    private static let defaultsKey = "ignoredResiduePaths"

    static func ignore(path: String, kind: Kind, days: Int = 7) {
        var entries = all()
        let until = kind == .temporary ? Date().addingTimeInterval(TimeInterval(days * 86_400)) : nil
        entries[path] = Entry(path: path, kind: kind, until: until)
        save(entries)
    }

    static func unignore(path: String) {
        var entries = all()
        entries.removeValue(forKey: path)
        save(entries)
    }

    static func status(of path: String) -> Status {
        var entries = all()
        guard let entry = entries[path] else { return .none }
        switch entry.kind {
        case .permanent:
            return .permanent
        case .temporary:
            if let until = entry.until, until > Date() {
                return .temporary(until: until)
            }
            entries.removeValue(forKey: path)
            save(entries)
            return .none
        }
    }

    static func all() -> [String: Entry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func listIgnored() -> [Entry] {
        all().values.sorted { $0.path < $1.path }
    }

    private static func save(_ entries: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

import Foundation

/// Heuristically finds leftovers of apps that are no longer installed:
/// Application Support folders, caches, preferences, saved state, HTTP
/// storage and logs, all under the current user's home directory.
enum ResidueScanner {

    private struct InstalledApp {
        let name: String
        let normalizedName: String
        let bundleID: String?
    }

    static func scanResidue(kinds: Set<ResidueKind>) -> [ScannedEntry] {
        let installed = installedApps()
        let installedNormNames = Set(installed.map(\.normalizedName))
        let installedBundleIDs = Set(installed.compactMap(\.bundleID))
        let currentApp = "CruftX"

        var entries: [ScannedEntry] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library", isDirectory: true)

        // Folders and caches first; these give us the list of "candidate" apps.
        var candidates: Set<String> = []

        if kinds.contains(.applicationSupport) {
            let dir = lib.appendingPathComponent("Application Support", isDirectory: true)
            let found = orphanFolders(
                in: dir,
                kind: .applicationSupport,
                installedNormNames: installedNormNames,
                installedBundleIDs: installedBundleIDs,
                currentApp: currentApp
            )
            candidates.formUnion(found.compactMap(\.appName).map(Self.normalize))
            entries += found
        }

        if kinds.contains(.caches) {
            let dir = lib.appendingPathComponent("Caches", isDirectory: true)
            let found = orphanFolders(
                in: dir,
                kind: .caches,
                installedNormNames: installedNormNames,
                installedBundleIDs: installedBundleIDs,
                currentApp: currentApp
            )
            candidates.formUnion(found.compactMap(\.appName).map(Self.normalize))
            entries += found
        }

        if kinds.contains(.httpStorage) {
            let dir = lib.appendingPathComponent("HTTPStorages", isDirectory: true)
            let found = orphanBundleIDFolders(
                in: dir,
                kind: .httpStorage,
                installedBundleIDs: installedBundleIDs,
                currentApp: currentApp
            )
            candidates.formUnion(found.compactMap(\.appName).map(Self.normalize))
            entries += found
        }

        if kinds.contains(.savedState) {
            let dir = lib.appendingPathComponent("Saved Application State", isDirectory: true)
            let found = orphanSavedState(
                in: dir,
                installedBundleIDs: installedBundleIDs,
                currentApp: currentApp
            )
            candidates.formUnion(found.compactMap(\.appName).map(Self.normalize))
            entries += found
        }

        if kinds.contains(.logs) {
            let dir = lib.appendingPathComponent("Logs", isDirectory: true)
            let found = orphanLogs(
                in: dir,
                installedNormNames: installedNormNames,
                installedBundleIDs: installedBundleIDs,
                currentApp: currentApp
            )
            candidates.formUnion(found.compactMap(\.appName).map(Self.normalize))
            entries += found
        }

        if kinds.contains(.preferences) {
            let dir = lib.appendingPathComponent("Preferences", isDirectory: true)
            entries += orphanPreferences(
                in: dir,
                installedBundleIDs: installedBundleIDs,
                candidates: candidates,
                currentApp: currentApp
            )
        }

        return entries
    }

    // MARK: - App discovery

    private static func installedApps() -> [InstalledApp] {
        var result: [InstalledApp] = []
        let fm = FileManager.default
        var searchDirs = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true)
        ]
        searchDirs.append(fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true))

        for dir in searchDirs {
            guard let urls = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in urls where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                let bundle = Bundle(url: url)
                result.append(InstalledApp(
                    name: name,
                    normalizedName: Self.normalize(name),
                    bundleID: bundle?.bundleIdentifier
                ))
            }
        }
        return result
    }

    // MARK: - Per-location scans

    private static func orphanFolders(
        in directory: URL,
        kind: ResidueKind,
        installedNormNames: Set<String>,
        installedBundleIDs: Set<String>,
        currentApp: String
    ) -> [ScannedEntry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let systemNames = systemExclusions()
        return urls.compactMap { url -> ScannedEntry? in
            let name = url.lastPathComponent
            let normalized = Self.normalize(name)
            guard !normalized.isEmpty else { return nil }
            guard !systemNames.contains(normalized) else { return nil }
            guard !name.lowercased().hasPrefix("com.apple") else { return nil }
            guard normalized != Self.normalize(currentApp) else { return nil }

            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values?.isSymbolicLink == true { return nil }

            // Skip anything that looks like an installed app.
            if matchesAnyInstalledFolder(
                normalized: normalized,
                installedNormNames: installedNormNames,
                installedBundleIDs: installedBundleIDs
            ) {
                return nil
            }

            guard let size = entrySize(at: url), size > 0 else { return nil }
            return ScannedEntry(
                name: name,
                path: url,
                sizeBytes: size,
                kind: nil,
                residueKind: kind,
                appName: displayName(for: name)
            )
        }
    }

    private static func orphanBundleIDFolders(
        in directory: URL,
        kind: ResidueKind,
        installedBundleIDs: Set<String>,
        currentApp: String
    ) -> [ScannedEntry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url -> ScannedEntry? in
            let name = url.lastPathComponent
            guard isBundleID(name) else { return nil }
            guard !name.lowercased().hasPrefix("com.apple") else { return nil }
            guard !name.lowercased().contains(Self.normalize(currentApp)) else { return nil }
            guard !matchesAnyInstalled(bundleID: name, installed: installedBundleIDs) else { return nil }

            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values?.isSymbolicLink == true { return nil }
            guard let size = entrySize(at: url), size > 0 else { return nil }

            return ScannedEntry(
                name: name,
                path: url,
                sizeBytes: size,
                kind: nil,
                residueKind: kind,
                appName: displayName(for: name)
            )
        }
    }

    private static func orphanSavedState(
        in directory: URL,
        installedBundleIDs: Set<String>,
        currentApp: String
    ) -> [ScannedEntry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url -> ScannedEntry? in
            let name = url.lastPathComponent
            guard name.hasSuffix(".savedState") else { return nil }
            let base = String(name.dropLast(".savedState".count))
            guard !base.lowercased().hasPrefix("com.apple") else { return nil }
            guard !base.lowercased().contains(Self.normalize(currentApp)) else { return nil }
            guard !matchesAnyInstalled(bundleID: base, installed: installedBundleIDs) else { return nil }

            guard let size = entrySize(at: url), size > 0 else { return nil }
            return ScannedEntry(
                name: name,
                path: url,
                sizeBytes: size,
                kind: nil,
                residueKind: .savedState,
                appName: displayName(for: base)
            )
        }
    }

    private static func orphanLogs(
        in directory: URL,
        installedNormNames: Set<String>,
        installedBundleIDs: Set<String>,
        currentApp: String
    ) -> [ScannedEntry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url -> ScannedEntry? in
            let name = url.lastPathComponent
            guard name != "DiagnosticReports" else { return nil }
            guard !name.lowercased().hasPrefix("com.apple") else { return nil }
            guard Self.normalize(name) != Self.normalize(currentApp) else { return nil }

            let normalized = Self.normalize(name)
            if installedNormNames.contains(normalized) { return nil }
            if isBundleID(name), matchesAnyInstalled(bundleID: name, installed: installedBundleIDs) { return nil }

            guard let size = entrySize(at: url), size > 0 else { return nil }
            return ScannedEntry(
                name: name,
                path: url,
                sizeBytes: size,
                kind: nil,
                residueKind: .logs,
                appName: displayName(for: name)
            )
        }
    }

    private static func orphanPreferences(
        in directory: URL,
        installedBundleIDs: Set<String>,
        candidates: Set<String>,
        currentApp: String
    ) -> [ScannedEntry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url -> ScannedEntry? in
            let name = url.lastPathComponent
            guard name.hasSuffix(".plist") else { return nil }
            let base = String(name.dropLast(".plist".count))
            guard isBundleID(base) else { return nil }
            guard !base.lowercased().hasPrefix("com.apple") else { return nil }
            guard !base.lowercased().contains(Self.normalize(currentApp)) else { return nil }
            guard !matchesAnyInstalled(bundleID: base, installed: installedBundleIDs) else { return nil }

            // Only report preferences that relate to a candidate orphan app,
            // or a well-formed bundle ID that clearly names an app.
            let appNorm = Self.normalize(displayName(for: base))
            let normalized = Self.normalize(base)
            guard candidates.contains(appNorm) || candidates.contains(normalized) else { return nil }

            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            if values?.isSymbolicLink == true { return nil }
            let size = Int64(values?.fileSize ?? 0)
            guard size > 0 else { return nil }

            return ScannedEntry(
                name: name,
                path: url,
                sizeBytes: size,
                kind: nil,
                residueKind: .preferences,
                appName: displayName(for: base)
            )
        }
    }

    // MARK: - Matching helpers

    private static func matchesAnyInstalled(bundleID: String, installed: Set<String>) -> Bool {
        let normalized = Self.normalize(bundleID)
        return installed.contains { Self.normalize($0) == normalized || normalized.hasPrefix(Self.normalize($0)) }
    }

    /// Matches a folder name against installed apps, both by exact name and
    /// by containment in app names / bundle IDs (e.g. "Code" matches
    /// "Visual Studio Code", "bilibili" matches "com.bilibili.app.mac").
    private static func matchesAnyInstalledFolder(
        normalized: String,
        installedNormNames: Set<String>,
        installedBundleIDs: Set<String>
    ) -> Bool {
        if installedNormNames.contains(normalized) { return true }
        // Short names are too generic for containment matching.
        guard normalized.count >= 4 else { return false }
        return installedBundleIDs.contains { Self.normalize($0).contains(normalized) }
            || installedNormNames.contains { $0.contains(normalized) }
    }

    static func isBundleID(_ string: String) -> Bool {
        string.contains(".") && !string.contains(" ")
    }

    /// Extracts a bundle identifier from an entry name, tolerating suffixes
    /// like ".plist" or ".savedState".
    static func bundleID(from name: String) -> String? {
        var candidate = name
        for suffix in [".plist", ".savedState"] where candidate.hasSuffix(suffix) {
            candidate = String(candidate.dropLast(suffix.count))
        }
        return isBundleID(candidate) ? candidate : nil
    }

    private static func entrySize(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        if values?.isDirectory == true {
            return JunkScanner.directorySize(at: url)
        }
        return Int64(values?.fileSize ?? 0)
    }

    private static func systemExclusions() -> Set<String> {
        let names = [
            "Apple", "AppleEvents", "CallHistoryDB", "CloudStorage", "CoreData",
            "CrashReporter", "DiagnosticReports", "Google", "Microsoft",
            "Printers", "SyncServices", "Xcode", "Developer", "Logs",
            "AddressBook", "Assistant", "Audio", "Knowledge", "Messages",
            "Reminders", "Safari", "ScreenTime", "Shortcuts", "Siri",
            "SoftwareUpdate", "Stocks", "Weather", "Mail", "Calendar",
            "Contacts", "Photos", "Maps", "Music", "Notes", "Numbers",
            "Pages", "Podcasts", "Preview", "Screenshot", "TextInputSources",
            "VoiceMemos", "WhatsApp", "Animoji", "DiskImages",
            "networkserviceproxy", "default.store", "default.store-shm",
            "default.store-wal", "icdd", "iCloud", "Codex", "OpenAI"
        ]
        return Set(names.map(Self.normalize))
    }

    static func normalize(_ string: String) -> String {
        string.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func displayName(for bundleOrName: String) -> String {
        guard isBundleID(bundleOrName) else { return bundleOrName }
        if let known = CommonApps.displayName(for: bundleOrName) {
            return known
        }
        var components = bundleOrName.split(separator: ".").map(String.init)
        // Drop the reverse-DNS prefix, e.g. "com." / "io." / "cn.".
        if let first = components.first,
           ["com", "cn", "org", "io", "net", "me", "co", "app", "dev", "www"].contains(first.lowercased()) {
            components.removeFirst()
        }

        let genericWords: Set<String> = [
            "pro", "app", "mac", "desktop", "client", "mobile", "hd", "web",
            "helper", "agent", "service", "daemon", "extension", "today",
            "widget", "share", "main", "core", "lite", "beta", "test", "dev",
            "macos", "osx", "suite", "plugin", "appex", "xpc"
        ]

        var chosen = components.last ?? bundleOrName
        for component in components.reversed() {
            var cleaned = component
            for prefix in ["mac-", "macos-", "osx-"] where cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
            if cleaned.lowercased().hasSuffix("-mac") {
                cleaned = String(cleaned.dropLast(4))
            }
            guard !cleaned.isEmpty, !genericWords.contains(cleaned.lowercased()) else { continue }
            chosen = cleaned
            break
        }
        return splitCamelCase(chosen)
    }

    private static func splitCamelCase(_ string: String) -> String {
        var result = ""
        for (index, char) in string.enumerated() {
            if char.isUppercase, index > 0 {
                let previous = string[string.index(string.startIndex, offsetBy: index - 1)]
                if previous.isLowercase || previous.isNumber {
                    result.append(" ")
                }
            }
            result.append(char)
        }
        return result
    }
}

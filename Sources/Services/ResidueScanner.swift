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

        // Sandboxed apps keep user data in Containers / Group Containers.
        // Only bundle-ID-shaped names are considered, so this stays precise.
        if kinds.contains(.containers) {
            for dirName in ["Containers", "Group Containers"] {
                let dir = lib.appendingPathComponent(dirName, isDirectory: true)
                let found = orphanBundleIDFolders(
                    in: dir,
                    kind: .containers,
                    installedBundleIDs: installedBundleIDs,
                    currentApp: currentApp
                )
                candidates.formUnion(found.compactMap(\.appName).map(Self.normalize))
                entries += found
            }
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
        let genericNames = genericFolderNames()
        return urls.compactMap { url -> ScannedEntry? in
            let name = url.lastPathComponent
            let normalized = Self.normalize(name)
            guard !normalized.isEmpty else { return nil }
            guard !systemNames.contains(normalized) else { return nil }
            guard !genericNames.contains(normalized) else { return nil }
            guard normalized.count >= 3 else { return nil }
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

            // A cache or log written in the last 24h is probably still in
            // use; treat it as "not residue" to avoid deleting active data.
            if kind == .caches, isModifiedWithin(url, hours: 24) { return nil }

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
            let base = Self.stripGroupPrefix(name)
            guard !base.lowercased().hasPrefix("com.apple") else { return nil }
            guard !base.lowercased().contains(Self.normalize(currentApp)) else { return nil }
            guard !matchesAnyInstalled(bundleID: name, installed: installedBundleIDs) else { return nil }

            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values?.isSymbolicLink == true { return nil }
            if kind == .caches, isModifiedWithin(url, hours: 24) { return nil }
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

            if isModifiedWithin(url, hours: 24) { return nil }
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
        var key = Self.normalize(bundleID)
        if key.hasPrefix("group") {
            key = String(key.dropFirst(5))
        }
        return installed.contains { raw in
            let installedNorm = Self.normalize(raw)
            return key == installedNorm
                || key.hasPrefix(installedNorm)
                || (key.contains(installedNorm) && installedNorm.count >= 8)
        }
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
        // Bundle-ID prefix match: com.tencent.LemonMonitor clearly belongs to
        // installed com.tencent.Lemon (legacy bundle ID change).
        if installedBundleIDs.contains(where: { normalized.hasPrefix(Self.normalize($0)) }) {
            return true
        }
        // Short names are too generic for containment matching.
        guard normalized.count >= 4 else { return false }
        let installedNames = installedNormNames
            .union(installedBundleIDs.map(Self.normalize))
            .filter { $0.count >= 5 }
        // The folder is contained in an installed name, or shares a
        // significant token with it (e.g. "LemonMonitor" vs "Tencent Lemon").
        return installedNames.contains { $0.contains(normalized) }
            || installedNames.contains { sharesSignificantToken(normalized, with: $0) }
    }

    /// A longest common substring of >= 5 chars means the folder name is too
    /// close to an installed app's name/bundle ID to safely call it residue.
    private static func sharesSignificantToken(_ lhs: String, with rhs: String) -> Bool {
        guard lhs.count >= 5, rhs.count >= 5 else { return false }
        let a = Array(lhs)
        let b = Array(rhs)
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        var best = 0
        for i in 1...a.count {
            for j in 1...b.count where a[i - 1] == b[j - 1] {
                table[i][j] = table[i - 1][j - 1] + 1
                if table[i][j] > best {
                    best = table[i][j]
                }
            }
        }
        return best >= 5
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

    /// Names too generic to call "residue of a removed app" without strong
    /// evidence. They are skipped in name-based scans (bundle-ID folders in
    /// Containers/Preferences are still matched exactly).
    private static func genericFolderNames() -> Set<String> {
        let names = [
            "Accounts", "AddressBook", "AirPlay", "Audio", "Automator",
            "Backups", "BackgroundTaskManagementAgent", "Cache", "Caches",
            "Calendar", "Clock", "Cloud", "CloudDocs", "Components", "Contacts",
            "Containers", "CoreAudio", "CoreData", "CoreDuet", "CoreLocation",
            "CoreSimulator", "Crashpad", "Data", "Database", "Databases",
            "Desktop", "Developer", "Diagnostics", "Dictionaries", "DiskImages",
            "Documents", "Downloads", "Extensions", "Files", "FindMy", "Fonts",
            "Frameworks", "Group Containers", "HomeKit", "Image Capture",
            "Installers", "Internet Plug-Ins", "Keyboard", "Keychains",
            "LaunchAgents", "LaunchDaemons", "Libraries", "Mail", "Maps",
            "Media", "Messages", "Metadata", "MobileDevice", "Music", "Notes",
            "Photos", "Plugins", "Preferences", "Printers", "Public",
            "Records", "Scripts", "Security", "Services", "Shared", "Spaces",
            "Storage", "Support", "SyncServices", "System", "Temp", "Temporary",
            "TextInputSources", "Tools", "Trash", "Updates", "User", "Users",
            "Utilities", "Weather", "Web", "WebKit", "Widgets", "WindowServer"
        ]
        return Set(names.map(Self.normalize))
    }

    /// True when the item's content modification date is within the given
    /// number of hours, indicating the folder is likely still in use.
    private static func isModifiedWithin(_ url: URL, hours: Double) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let date = values.contentModificationDate else {
            return false
        }
        return Date().timeIntervalSince(date) < hours * 3600
    }

    /// "group.com.example.App" -> "com.example.App"; other names unchanged.
    private static func stripGroupPrefix(_ name: String) -> String {
        if name.lowercased().hasPrefix("group.") {
            return String(name.dropFirst("group.".count))
        }
        return name
    }

    static func normalize(_ string: String) -> String {
        string.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func displayName(for bundleOrName: String) -> String {
        CommonApps.displayName(for: bundleOrName) ?? bundleOrName
    }
}

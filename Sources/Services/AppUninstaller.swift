import Foundation

/// App uninstall tool: lists installed apps and moves an app (and optionally
/// its user data) to the Trash.
enum AppUninstaller {

    struct RelatedItem: Identifiable, Sendable {
        let id: String
        let name: String
        let path: URL
        let sizeBytes: Int64
    }

    /// Lists apps from /Applications and ~/Applications (system apps and
    /// CruftX itself are excluded).
    static func scanInstalledApps() -> [InstalledAppInfo] {
        var result: [InstalledAppInfo] = []
        let fm = FileManager.default
        let dirs = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        for dir in dirs {
            guard let urls = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in urls where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                guard name != "CruftX" else { continue }
                let bundle = Bundle(url: url)
                let size = JunkScanner.directorySize(at: url)
                result.append(InstalledAppInfo(
                    id: url.path,
                    name: name,
                    path: url,
                    bundleID: bundle?.bundleIdentifier,
                    sizeBytes: size
                ))
            }
        }
        return result
    }

    /// Finds user data belonging to an app across the home Library.
    static func relatedData(for app: InstalledAppInfo) -> [RelatedItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library", isDirectory: true)
        let appNorm = ResidueScanner.normalize(app.name)
        let bundleNorm = app.bundleID.map(ResidueScanner.normalize) ?? ""

        var items: [RelatedItem] = []

        func matches(_ name: String) -> Bool {
            let normalized = ResidueScanner.normalize(name)
            return normalized == appNorm
                || (!bundleNorm.isEmpty && normalized == bundleNorm)
                || (!bundleNorm.isEmpty && normalized.hasPrefix(bundleNorm))
        }

        // Application Support, Caches, Logs: match by folder name.
        for dirName in ["Application Support", "Caches", "Logs"] {
            let dir = lib.appendingPathComponent(dirName, isDirectory: true)
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in urls where matches(url.lastPathComponent) {
                let size = JunkScanner.directorySize(at: url)
                if size > 0 {
                    items.append(RelatedItem(id: url.path, name: url.lastPathComponent, path: url, sizeBytes: size))
                }
            }
        }

        // Saved Application State: <bundleID>.savedState
        if let bundleID = app.bundleID {
            let dir = lib.appendingPathComponent("Saved Application State", isDirectory: true)
            let target = "\(bundleID).savedState"
            let url = dir.appendingPathComponent(target)
            if FileManager.default.fileExists(atPath: url.path) {
                let size = JunkScanner.directorySize(at: url)
                if size > 0 {
                    items.append(RelatedItem(id: url.path, name: target, path: url, sizeBytes: size))
                }
            }
        }

        // HTTPStorages: <bundleID>
        if let bundleID = app.bundleID {
            let dir = lib.appendingPathComponent("HTTPStorages", isDirectory: true)
            let url = dir.appendingPathComponent(bundleID)
            if FileManager.default.fileExists(atPath: url.path) {
                let size = JunkScanner.directorySize(at: url)
                if size > 0 {
                    items.append(RelatedItem(id: url.path, name: bundleID, path: url, sizeBytes: size))
                }
            }
        }

        // Preferences: <bundleID>.plist and <bundleID>.*.plist
        if let bundleID = app.bundleID {
            let dir = lib.appendingPathComponent("Preferences", isDirectory: true)
            if let files = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                for url in files where url.lastPathComponent.hasPrefix("\(bundleID).")
                    && url.pathExtension == "plist" {
                    let size = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                    if size > 0 {
                        items.append(RelatedItem(id: url.path, name: url.lastPathComponent, path: url, sizeBytes: size))
                    }
                }
            }
        }

        // Containers and Group Containers (sandboxed apps like WeChat).
        if let bundleID = app.bundleID {
            let container = lib.appendingPathComponent("Containers/\(bundleID)", isDirectory: true)
            if FileManager.default.fileExists(atPath: container.path) {
                let size = JunkScanner.directorySize(at: container)
                if size > 0 {
                    items.append(RelatedItem(id: container.path, name: "Containers/\(bundleID)", path: container, sizeBytes: size))
                }
            }
            let groupDir = lib.appendingPathComponent("Group Containers", isDirectory: true)
            if let groupURLs = try? FileManager.default.contentsOfDirectory(
                at: groupDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for url in groupURLs where ResidueScanner.normalize(url.lastPathComponent).contains(bundleNorm) {
                    let size = JunkScanner.directorySize(at: url)
                    if size > 0 {
                        items.append(RelatedItem(id: url.path, name: "Group Containers/\(url.lastPathComponent)", path: url, sizeBytes: size))
                    }
                }
            }
        }

        return items
    }

    /// Moves the app bundle (and optionally related data) to the Trash.
    static func uninstall(app: InstalledAppInfo, includeData: Bool) -> CleanSummary {
        var items = [
            JunkItem(
                id: app.id,
                name: app.name,
                path: app.path,
                sizeBytes: app.sizeBytes,
                kind: nil,
                residueKind: nil,
                appName: app.name
            )
        ]
        if includeData {
            items += relatedData(for: app).map {
                JunkItem(
                    id: $0.id,
                    name: $0.name,
                    path: $0.path,
                    sizeBytes: $0.sizeBytes,
                    kind: nil,
                    residueKind: nil,
                    appName: app.name
                )
            }
        }
        return Cleaner.clean(items)
    }
}

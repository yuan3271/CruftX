import Foundation

/// Specialized cleaning for office / chat apps.
///
/// WeChat gets a deep scan of its `FileStorage` cache folders (images, video,
/// files, temp). Chat history lives under the `Message` directory and is
/// deliberately never scanned. Other office apps only have their cache
/// directories scanned, which is safe by construction.
enum OfficeCleaner {

    static func scan() -> [OfficeScanGroup] {
        var groups: [OfficeScanGroup] = []

        if let wechat = scanWeChat() {
            groups.append(wechat)
        }

        let genericApps: [(name: String, bundleID: String)] = [
            ("企业微信", "com.tencent.wework"),
            ("QQ", "com.tencent.qq"),
            ("钉钉", "com.laiwang.DingTalk"),
            ("飞书", "com.larksuite.suite"),
            ("腾讯会议", "com.tencent.meeting")
        ]
        for app in genericApps {
            if let group = scanGenericCaches(appName: app.name, bundleID: app.bundleID) {
                groups.append(group)
            }
        }

        return groups
    }

    // MARK: - WeChat deep scan

    private static func scanWeChat() -> OfficeScanGroup? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var entries: [ScannedEntry] = []

        // WeChat 4.x: sandboxed container with tmp + Documents.
        let container = home.appendingPathComponent("Library/Containers/com.tencent.xinWeChat/Data", isDirectory: true)
        entries += weChatV4Entries(container: container)

        // WeChat 3.x legacy: Application Support/.../FileStorage layout.
        let legacyBases = [
            home.appendingPathComponent("Library/Containers/com.tencent.xinWeChat/Data/Library/Application Support/com.tencent.xinWeChat", isDirectory: true),
            home.appendingPathComponent("Library/Application Support/com.tencent.xinWeChat", isDirectory: true)
        ]
        for base in legacyBases {
            entries += fileStorageRoots(in: base).flatMap(scanFileStorage)
        }

        guard !entries.isEmpty else { return nil }

        let branches = Self.groupIntoBranches(entries, appName: "微信")
        return OfficeScanGroup(id: "wechat", appName: "微信", bundleID: "com.tencent.xinWeChat", branches: branches)
    }

    /// WeChat 4.x keeps chat databases under `xwechat_files/<wxid>/db_storage`
    /// and media caches under `msg/{attach,video,file}`. We only touch the
    /// media/temp/cache folders and never descend into db_storage.
    private static func weChatV4Entries(container: URL) -> [ScannedEntry] {
        var entries: [ScannedEntry] = []
        let fm = FileManager.default

        func add(_ url: URL, kind: OfficeKind, label: String) {
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let size = JunkScanner.directorySize(at: url)
            guard size > 0 else { return }
            entries.append(ScannedEntry(
                name: label,
                path: url,
                sizeBytes: size,
                kind: nil,
                residueKind: nil,
                officeKind: kind,
                appName: "微信"
            ))
        }

        // 临时文件: Data/tmp holds CFNetworkDownload temp files.
        add(container.appendingPathComponent("tmp", isDirectory: true), kind: .tempCache, label: "下载临时文件")

        // 应用/网页缓存 under app_data/radium.
        let radium = container.appendingPathComponent("Documents/app_data/radium", isDirectory: true)
        add(radium.appendingPathComponent("cache", isDirectory: true), kind: .appCache, label: "应用缓存 (radium/cache)")
        add(radium.appendingPathComponent("web", isDirectory: true), kind: .appCache, label: "网页缓存")
        add(radium.appendingPathComponent("xfile/cache", isDirectory: true), kind: .appCache, label: "文件缓存 (xfile)")
        add(radium.appendingPathComponent("xeditor/cache", isDirectory: true), kind: .appCache, label: "编辑器缓存")
        add(container.appendingPathComponent("Library/Caches", isDirectory: true), kind: .appCache, label: "容器缓存")

        // 每个账号的媒体缓存: msg/attach (images), msg/video, msg/file.
        let filesRoot = container.appendingPathComponent("Documents/xwechat_files", isDirectory: true)
        guard let userDirs = try? fm.contentsOfDirectory(
            at: filesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return entries
        }

        for userDir in userDirs {
            let name = userDir.lastPathComponent
            guard name.hasPrefix("wxid_") else { continue }
            let msg = userDir.appendingPathComponent("msg", isDirectory: true)
            add(msg.appendingPathComponent("attach", isDirectory: true), kind: .imageCache, label: "图片缓存（\(name)）")
            add(msg.appendingPathComponent("video", isDirectory: true), kind: .videoCache, label: "视频缓存（\(name)）")
            add(msg.appendingPathComponent("file", isDirectory: true), kind: .fileCache, label: "文件缓存（\(name)）")
        }

        return entries
    }

    /// Finds every `FileStorage` cache root under a WeChat data base,
    /// without descending into Message (chat history) or Backup folders.
    private static func fileStorageRoots(in base: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: base.path) else { return [] }
        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var roots: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            let path = url.path
            let components = path.lowercased().split(separator: "/")
            if components.contains("message") || components.contains("backup") {
                enumerator.skipDescendants()
                continue
            }
            if url.lastPathComponent == "FileStorage" {
                roots.append(url)
                enumerator.skipDescendants()
            }
        }
        return roots
    }

    private static func scanFileStorage(_ root: URL) -> [ScannedEntry] {
        guard let subdirs = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return subdirs.compactMap { url -> ScannedEntry? in
            let name = url.lastPathComponent
            guard name != "Message" else { return nil }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { return nil }

            let size = JunkScanner.directorySize(at: url)
            guard size > 0 else { return nil }

            return ScannedEntry(
                name: name,
                path: url,
                sizeBytes: size,
                kind: nil,
                residueKind: nil,
                officeKind: officeKind(for: name),
                appName: "微信"
            )
        }
    }

    private static func officeKind(for folderName: String) -> OfficeKind {
        switch folderName.lowercased() {
        case "image", "image2", "thumb", "thumbs":
            return .imageCache
        case "video", "video2":
            return .videoCache
        case "file", "files":
            return .fileCache
        case "temp", "tmp":
            return .tempCache
        default:
            return .otherCache
        }
    }

    // MARK: - Generic cache scan for other office apps

    private static func scanGenericCaches(appName: String, bundleID: String) -> OfficeScanGroup? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var cacheDirs = [
            home.appendingPathComponent("Library/Caches/\(bundleID)", isDirectory: true),
            home.appendingPathComponent("Library/Containers/\(bundleID)/Data/Library/Caches", isDirectory: true)
        ]
        cacheDirs = cacheDirs.filter { FileManager.default.fileExists(atPath: $0.path) }

        let entries = cacheDirs.compactMap { url -> ScannedEntry? in
            let size = JunkScanner.directorySize(at: url)
            guard size > 0 else { return nil }
            return ScannedEntry(
                name: url.lastPathComponent,
                path: url,
                sizeBytes: size,
                kind: nil,
                residueKind: nil,
                officeKind: .appCache,
                appName: appName
            )
        }
        guard !entries.isEmpty else { return nil }
        let branches = Self.groupIntoBranches(entries, appName: appName)
        return OfficeScanGroup(id: bundleID, appName: appName, bundleID: bundleID, branches: branches)
    }

    // MARK: - Branch grouping (one branch per OfficeKind)

    private static func groupIntoBranches(_ entries: [ScannedEntry], appName: String) -> [ScanGroup] {
        let grouped = Dictionary(grouping: entries) { $0.officeKind ?? .otherCache }
        return OfficeKind.allCases.compactMap { kind -> ScanGroup? in
            guard let items = grouped[kind], !items.isEmpty else { return nil }
            return ScanGroup(
                id: "\(appName)-\(kind.rawValue)",
                title: kind.title,
                icon: kind.icon,
                detail: nil,
                items: items.map { entry in
                    JunkItem(
                        id: entry.id,
                        name: entry.name,
                        path: entry.path,
                        sizeBytes: entry.sizeBytes,
                        kind: entry.kind,
                        residueKind: entry.residueKind,
                        officeKind: entry.officeKind,
                        appName: entry.appName,
                        isSelected: false
                    )
                }.sorted { $0.sizeBytes > $1.sizeBytes }
            )
        }
    }
}

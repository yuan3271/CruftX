import AppKit
import SwiftUI

/// Central state holder for the app. All published state is main-actor bound.
@MainActor
final class ScanStore: ObservableObject {
    @Published var dailyGroups: [ScanGroup] = []
    @Published var residueGroups: [ScanGroup] = []
    @Published var ignoredResidueGroups: [ScanGroup] = []
    @Published var installedApps: [InstalledAppInfo] = []
    @Published var recycleEntries: [RecycleBin.Entry] = []
    @Published var updateInfo: UpdateInfo?
    @Published var isCheckingUpdate = false
    @Published var isDownloadingUpdate = false
    @Published var updateMessage: String?
    @Published var isScanning = false
    @Published var progressText = L10n.tr("status_ready", default: "准备就绪")
    @Published var lastMessage: String?
    @Published var lastError: String?

    @AppStorage("cleanupDestination") var cleanupDestination = "trash"

    @Published var includeCaches = true
    @Published var includeLogs = true
    @Published var includeDiagnostics = true
    @Published var includeDerivedData = true
    @Published var includeTempFiles = true
    @Published var includeOffice = true

    @Published var includeAppSupport = true
    @Published var includeContainers = true
    @Published var includePrefs = true
    @Published var includeSavedState = true
    @Published var includeHTTPStorage = true

    var allItems: [JunkItem] {
        dailyGroups.flatMap(\.items) + residueGroups.flatMap(\.items)
    }

    var totalBytes: Int64 {
        allItems.reduce(0) { $0 + $1.sizeBytes }
    }

    var totalSizeText: String {
        totalBytes.fileSizeText
    }

    var itemCount: Int {
        allItems.count
    }

    var lowRiskCount: Int { allItems.filter { $0.risk == .low }.count }
    var mediumRiskCount: Int { allItems.filter { $0.risk == .medium }.count }
    var highRiskCount: Int { allItems.filter { $0.risk == .high }.count }

    var lowRiskBytes: Int64 { allItems.filter { $0.risk == .low }.reduce(0) { $0 + $1.sizeBytes } }
    var mediumRiskBytes: Int64 { allItems.filter { $0.risk == .medium }.reduce(0) { $0 + $1.sizeBytes } }
    var highRiskBytes: Int64 { allItems.filter { $0.risk == .high }.reduce(0) { $0 + $1.sizeBytes } }

    var dailySelectedBytes: Int64 {
        dailyGroups.flatMap(\.items).filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
    }

    var residueSelectedBytes: Int64 {
        residueGroups.flatMap(\.items).filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
    }

    var hasScanned: Bool {
        !dailyGroups.isEmpty || !residueGroups.isEmpty || !ignoredResidueGroups.isEmpty
    }

    /// Daily junk grouped by software instead of content kind. Items without
    /// a recognizable app land in "System / Other".
    var dailyGroupsByApp: [ScanGroup] {
        let items = dailyGroups.flatMap(\.items)
        let grouped = Dictionary(grouping: items) { appKey(for: $0) }
        return grouped.keys.sorted().compactMap { key in
            guard let groupItems = grouped[key] else { return nil }
            let sorted = groupItems.sorted { $0.sizeBytes > $1.sizeBytes }
            guard let first = sorted.first else { return nil }
            let isSystem = key == Self.systemOtherKey
            let title = resolvedAppName(for: first) ?? L10n.tr("system_other", default: "系统 / 其他")
            return ScanGroup(
                id: "app-\(key)",
                title: title,
                icon: isSystem ? "gearshape" : "app.badge",
                detail: isSystem ? L10n.tr("system_other_detail", default: "无法归属到具体应用的通用系统内容") : nil,
                items: sorted
            )
        }
    }

    var cleanupDestinationIsRecycle: Bool {
        Self.destinationValue == "recycle"
    }

    // MARK: - Scanning

    func startScan() async {
        guard !isScanning else { return }
        isScanning = true
        progressText = L10n.tr("scanning", default: "正在扫描…")
        lastError = nil

        let enabledKinds = enabledJunkKinds()
        let enabledResidue = enabledResidueKinds()
        let scanOffice = includeOffice

        let (dailyEntries, residueEntries, officeGroups) = await Task.detached(priority: .userInitiated) {
            let daily = JunkScanner.scanDailyJunk(kinds: enabledKinds)
            let residue = ResidueScanner.scanResidue(kinds: enabledResidue)
            let office = scanOffice ? OfficeCleaner.scan() : []
            return (daily, residue, office)
        }.value

        var groups = Self.groupDaily(dailyEntries)
        if let officeGroup = Self.groupOffice(officeGroups) {
            groups.append(officeGroup)
        }
        dailyGroups = groups
        let (active, ignored) = partitionByIgnoreStatus(residueEntries)
        residueGroups = Self.groupResidue(active)
        ignoredResidueGroups = Self.groupResidue(ignored)
        progressText = L10n.tr("scan_done", default: "扫描完成")
        isScanning = false
    }

    func clean(_ items: [JunkItem]) async {
        guard !items.isEmpty else { return }
        isScanning = true
        progressText = L10n.tr("cleaning", default: "正在清理…")

        let destination = Self.destinationValue
        let summary = await Task.detached(priority: .userInitiated) {
            Cleaner.clean(items, destination: destination)
        }.value

        removeCleaned(items)
        progressText = L10n.tr("clean_done", default: "清理完成")
        if destination == "recycle" {
            lastMessage = L10n.tr("clean_summary_recycle", default: "已移动 %d 项到回收站，共 %@", summary.itemCount, summary.freedText)
            refreshRecycleBin()
        } else {
            lastMessage = L10n.tr("clean_summary_trash", default: "已清理 %d 项，释放 %@", summary.itemCount, summary.freedText)
        }
        if !summary.failedPaths.isEmpty {
            lastError = L10n.tr("clean_failed", default: "有 %d 项未能清理（可能正被占用）：%@", summary.failedPaths.count, summary.failedPaths.prefix(3).joined(separator: "、"))
        }
        isScanning = false
    }

    // MARK: - Uninstall

    func loadInstalledApps() async {
        let apps = await Task.detached(priority: .userInitiated) {
            AppUninstaller.scanInstalledApps()
        }.value
        installedApps = apps.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    func uninstall(_ app: InstalledAppInfo, includeData: Bool) async -> CleanSummary {
        let summary = await Task.detached(priority: .userInitiated) {
            AppUninstaller.uninstall(app: app, includeData: includeData)
        }.value
        installedApps.removeAll { $0.id == app.id }
        return summary
    }

    // MARK: - Ignore management

    func ignoreResidue(_ items: [JunkItem], kind: IgnoreManager.Kind) {
        guard !items.isEmpty else { return }
        for item in items {
            IgnoreManager.ignore(path: item.path.path, kind: kind)
        }
        let ids = Set(items.map(\.id))

        var dropped: [JunkItem] = []
        residueGroups = residueGroups.compactMap { group in
            var keep: [JunkItem] = []
            for item in group.items {
                if ids.contains(item.id) {
                    dropped.append(item)
                } else {
                    keep.append(item)
                }
            }
            guard !keep.isEmpty else { return nil }
            return ScanGroup(id: group.id, title: group.title, icon: group.icon, detail: group.detail, subtitle: group.subtitle, items: keep)
        }

        if kind == .temporary, !dropped.isEmpty {
            merge(items: dropped, into: &ignoredResidueGroups)
        }
    }

    func unignoreResidue(_ items: [JunkItem]) {
        guard !items.isEmpty else { return }
        for item in items {
            IgnoreManager.unignore(path: item.path.path)
        }
        let ids = Set(items.map(\.id))
        var dropped: [JunkItem] = []
        ignoredResidueGroups = ignoredResidueGroups.compactMap { group in
            var keep: [JunkItem] = []
            for item in group.items {
                if ids.contains(item.id) {
                    dropped.append(item)
                } else {
                    keep.append(item)
                }
            }
            guard !keep.isEmpty else { return nil }
            return ScanGroup(id: group.id, title: group.title, icon: group.icon, detail: group.detail, subtitle: group.subtitle, items: keep)
        }
        if !dropped.isEmpty {
            merge(items: dropped, into: &residueGroups)
        }
    }

    func unignore(path: String) {
        IgnoreManager.unignore(path: path)
        for groupIndex in ignoredResidueGroups.indices {
            ignoredResidueGroups[groupIndex].items.removeAll { $0.path.path == path }
        }
        ignoredResidueGroups.removeAll { $0.items.isEmpty }
    }

    // MARK: - Recycle bin

    func refreshRecycleBin() {
        recycleEntries = RecycleBin.entries()
    }

    func restoreRecycleEntry(_ entry: RecycleBin.Entry) {
        if RecycleBin.restore(entry) {
            refreshRecycleBin()
        }
    }

    func deleteRecycleEntry(_ entry: RecycleBin.Entry) {
        if RecycleBin.delete(entry) {
            refreshRecycleBin()
        }
    }

    func emptyRecycleBin() {
        _ = RecycleBin.emptyAll()
        refreshRecycleBin()
    }

    // MARK: - Auto update

    func checkForUpdate(force: Bool = false) async {
        if !force {
            let last = UserDefaults.standard.object(forKey: "lastUpdateCheckDate") as? Date
            if let last, Date().timeIntervalSince(last) < 86_400 { return }
        }
        isCheckingUpdate = true
        do {
            let info = try await Task.detached(priority: .background) {
                try await UpdateChecker.checkLatest()
            }.value
            updateInfo = info
            updateMessage = nil
            if info != nil {
                UserDefaults.standard.set(Date(), forKey: "lastUpdateCheckDate")
            }
        } catch {
            updateInfo = nil
            updateMessage = L10n.tr("update_failed", default: "检查更新失败（暂无 Releases 或网络不可用）")
        }
        isCheckingUpdate = false
    }

    func downloadUpdate() async {
        guard let info = updateInfo else { return }
        isDownloadingUpdate = true
        do {
            let url = try await Task.detached(priority: .userInitiated) {
                try await UpdateChecker.download(info)
            }.value
            NSWorkspace.shared.activateFileViewerSelecting([url])
            updateMessage = L10n.tr("download_done", default: "下载完成，已打开安装镜像。")
        } catch {
            updateMessage = L10n.tr("download_failed", default: "下载失败：%@", error.localizedDescription)
        }
        isDownloadingUpdate = false
    }

    // MARK: - Selection helpers

    func reset() {
        dailyGroups = []
        residueGroups = []
        ignoredResidueGroups = []
        lastMessage = nil
        lastError = nil
        progressText = L10n.tr("status_ready", default: "准备就绪")
    }

    func toggleSelection(_ id: String) {
        for groupIndex in dailyGroups.indices {
            for itemIndex in dailyGroups[groupIndex].items.indices
            where dailyGroups[groupIndex].items[itemIndex].id == id {
                dailyGroups[groupIndex].items[itemIndex].isSelected.toggle()
                return
            }
        }
        for groupIndex in residueGroups.indices {
            for itemIndex in residueGroups[groupIndex].items.indices
            where residueGroups[groupIndex].items[itemIndex].id == id {
                residueGroups[groupIndex].items[itemIndex].isSelected.toggle()
                return
            }
        }
        for groupIndex in ignoredResidueGroups.indices {
            for itemIndex in ignoredResidueGroups[groupIndex].items.indices
            where ignoredResidueGroups[groupIndex].items[itemIndex].id == id {
                ignoredResidueGroups[groupIndex].items[itemIndex].isSelected.toggle()
                return
            }
        }
    }

    func selectAllDaily(_ selected: Bool) {
        for groupIndex in dailyGroups.indices {
            for itemIndex in dailyGroups[groupIndex].items.indices {
                dailyGroups[groupIndex].items[itemIndex].isSelected = selected
            }
        }
    }

    func selectAllResidue(_ selected: Bool) {
        for groupIndex in residueGroups.indices {
            for itemIndex in residueGroups[groupIndex].items.indices {
                residueGroups[groupIndex].items[itemIndex].isSelected = selected
            }
        }
    }

    func toggleGroup(_ groupID: String) {
        if groupID.hasPrefix("app-") {
            let key = String(groupID.dropFirst("app-".count))
            let matching = dailyGroups.flatMap(\.items).filter { appKey(for: $0) == key }
            guard !matching.isEmpty else { return }
            let allSelected = matching.allSatisfy(\.isSelected)
            for groupIndex in dailyGroups.indices {
                for itemIndex in dailyGroups[groupIndex].items.indices
                where appKey(for: dailyGroups[groupIndex].items[itemIndex]) == key {
                    dailyGroups[groupIndex].items[itemIndex].isSelected = !allSelected
                }
            }
            return
        }

        func toggle(_ groups: inout [ScanGroup]) {
            guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
            let items = groups[index].items
            let allSelected = items.allSatisfy(\.isSelected)
            for itemIndex in groups[index].items.indices {
                groups[index].items[itemIndex].isSelected = !allSelected
            }
        }
        toggle(&dailyGroups)
        toggle(&residueGroups)
        toggle(&ignoredResidueGroups)
    }

    // MARK: - Private helpers

    private static var destinationValue: String {
        UserDefaults.standard.string(forKey: "cleanupDestination") ?? "trash"
    }

    private func partitionByIgnoreStatus(_ entries: [ScannedEntry]) -> ([ScannedEntry], [ScannedEntry]) {
        var active: [ScannedEntry] = []
        var ignored: [ScannedEntry] = []
        for entry in entries {
            switch IgnoreManager.status(of: entry.path.path) {
            case .none:
                active.append(entry)
            case .temporary:
                ignored.append(entry)
            case .permanent:
                break
            }
        }
        return (active, ignored)
    }

    private func merge(items: [JunkItem], into groups: inout [ScanGroup]) {
        let grouped = Dictionary(grouping: items) { $0.appName?.lowercased() ?? "?" }
        for (key, groupItems) in grouped {
            if let index = groups.firstIndex(where: { $0.id == key }) {
                groups[index].items.append(contentsOf: groupItems)
            } else {
                let bundleID = groupItems.compactMap { ResidueScanner.bundleID(from: $0.name) }.first
                groups.append(ScanGroup(
                    id: key,
                    title: groupItems.first?.appName ?? key,
                    icon: "app.dashed",
                    detail: L10n.tr("temporarily_ignored", default: "暂时忽略"),
                    subtitle: bundleID,
                    items: groupItems
                ))
            }
        }
    }

    private func enabledJunkKinds() -> Set<JunkKind> {
        var set: Set<JunkKind> = []
        if includeCaches { set.insert(.caches) }
        if includeLogs { set.insert(.logs) }
        if includeDiagnostics { set.insert(.diagnosticReports) }
        if includeDerivedData { set.insert(.derivedData) }
        if includeTempFiles { set.insert(.tempFiles) }
        return set
    }

    private func enabledResidueKinds() -> Set<ResidueKind> {
        var set: Set<ResidueKind> = []
        if includeAppSupport { set.insert(.applicationSupport) }
        if includeContainers { set.insert(.containers) }
        if includePrefs { set.insert(.preferences) }
        if includeSavedState { set.insert(.savedState) }
        if includeHTTPStorage { set.insert(.httpStorage) }
        set.insert(.caches)
        set.insert(.logs)
        return set
    }

    private func removeCleaned(_ items: [JunkItem]) {
        let cleanedIDs = Set(items.map(\.id))
        dailyGroups = dailyGroups.map { group in
            ScanGroup(id: group.id, title: group.title, icon: group.icon, detail: group.detail,
                      subtitle: group.subtitle, items: group.items.filter { !cleanedIDs.contains($0.id) })
        }.filter { !$0.items.isEmpty }
        residueGroups = residueGroups.map { group in
            ScanGroup(id: group.id, title: group.title, icon: group.icon, detail: group.detail,
                      subtitle: group.subtitle, items: group.items.filter { !cleanedIDs.contains($0.id) })
        }.filter { !$0.items.isEmpty }
        ignoredResidueGroups = ignoredResidueGroups.map { group in
            ScanGroup(id: group.id, title: group.title, icon: group.icon, detail: group.detail,
                      subtitle: group.subtitle, items: group.items.filter { !cleanedIDs.contains($0.id) })
        }.filter { !$0.items.isEmpty }
    }

    private static func groupDaily(_ entries: [ScannedEntry]) -> [ScanGroup] {
        let grouped = Dictionary(grouping: entries.filter { $0.kind != nil }) { $0.kind! }
        return JunkKind.allCases.compactMap { kind in
            guard let items = grouped[kind], !items.isEmpty else { return nil }
            return ScanGroup(
                id: kind.rawValue,
                title: kind.title,
                icon: kind.icon,
                detail: kind.detail,
                items: items.map { JunkItem(
                    id: $0.id, name: $0.name, path: $0.path, sizeBytes: $0.sizeBytes,
                    kind: $0.kind, residueKind: $0.residueKind, officeKind: $0.officeKind,
                    appName: $0.appName, isSelected: kind.risk == .low)
                }.sorted { $0.sizeBytes > $1.sizeBytes }
            )
        }
    }

    /// Merges office/chat app cleaning into a single daily-junk branch so
    /// "办公专清" is part of the regular cleanup flow.
    private static func groupOffice(_ groups: [OfficeScanGroup]) -> ScanGroup? {
        let items = groups.flatMap { $0.branches.flatMap(\.items) }
            .map { item in
                JunkItem(
                    id: item.id,
                    name: item.name,
                    path: item.path,
                    sizeBytes: item.sizeBytes,
                    kind: item.kind,
                    residueKind: item.residueKind,
                    officeKind: item.officeKind,
                    appName: item.appName,
                    isSelected: item.isDefaultChecked
                )
            }
            .sorted { $0.sizeBytes > $1.sizeBytes }
        guard !items.isEmpty else { return nil }
        return ScanGroup(
            id: "officeCache",
            title: L10n.tr("office_cache_group_title", default: "办公软件缓存"),
            icon: "bubble.left.and.bubble.right",
            detail: L10n.tr("office_cache_group_detail", default: "微信、企业微信、QQ、钉钉、飞书等办公软件的缓存与临时文件"),
            items: items
        )
    }

    private static let systemOtherKey = "system-other"

    private func appKey(for item: JunkItem) -> String {
        resolvedAppName(for: item)?.lowercased() ?? Self.systemOtherKey
    }

    private func resolvedAppName(for item: JunkItem) -> String? {
        item.appName ?? CommonApps.appName(fromFolderName: item.name, kind: item.kind)
    }

    private static func groupResidue(_ entries: [ScannedEntry]) -> [ScanGroup] {
        let named = entries.filter { $0.appName != nil }
        let grouped = Dictionary(grouping: named) { $0.appName!.lowercased() }
        return grouped.keys.sorted().compactMap { key in
            let items = grouped[key]!
            let title = items.first?.appName ?? key
            let bundleID = items.lazy.compactMap { ResidueScanner.bundleID(from: $0.name) }.first
            return ScanGroup(
                id: key,
                title: title,
                icon: "app.dashed",
                detail: L10n.tr("residue_leftover_detail", default: "已卸载应用的遗留文件"),
                subtitle: bundleID,
                items: items.map { JunkItem(
                    id: $0.id, name: $0.name, path: $0.path, sizeBytes: $0.sizeBytes,
                    kind: $0.kind, residueKind: $0.residueKind, officeKind: $0.officeKind,
                    appName: $0.appName, isSelected: false)
                }.sorted { $0.sizeBytes > $1.sizeBytes }
            )
        }
    }
}

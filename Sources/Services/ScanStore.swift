import SwiftUI

/// Central state holder for the app. All published state is main-actor bound.
@MainActor
final class ScanStore: ObservableObject {
    @Published var dailyGroups: [ScanGroup] = []
    @Published var residueGroups: [ScanGroup] = []
    @Published var officeGroups: [OfficeScanGroup] = []
    @Published var installedApps: [InstalledAppInfo] = []
    @Published var isScanning = false
    @Published var progressText = "准备就绪"
    @Published var lastMessage: String?
    @Published var lastError: String?

    @Published var includeCaches = true
    @Published var includeLogs = true
    @Published var includeDiagnostics = true
    @Published var includeDerivedData = true
    @Published var includeTempFiles = true

    @Published var includeAppSupport = true
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

    var officeTotalBytes: Int64 {
        officeGroups.reduce(0) { $0 + $1.totalBytes }
    }

    var itemCount: Int {
        allItems.count
    }

    var dailySelectedBytes: Int64 {
        dailyGroups.flatMap(\.items).filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
    }

    var residueSelectedBytes: Int64 {
        residueGroups.flatMap(\.items).filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
    }

    var hasScanned: Bool {
        !dailyGroups.isEmpty || !residueGroups.isEmpty
    }

    func startScan() async {
        guard !isScanning else { return }
        isScanning = true
        progressText = "正在扫描…"
        lastError = nil

        let enabledKinds = enabledJunkKinds()
        let enabledResidue = enabledResidueKinds()

        let (dailyEntries, residueEntries) = await Task.detached(priority: .userInitiated) {
            let daily = JunkScanner.scanDailyJunk(kinds: enabledKinds)
            let residue = ResidueScanner.scanResidue(kinds: enabledResidue)
            return (daily, residue)
        }.value

        dailyGroups = Self.groupDaily(dailyEntries)
        residueGroups = Self.groupResidue(residueEntries)
        progressText = "扫描完成"

        isScanning = false
    }

    func clean(_ items: [JunkItem]) async {
        guard !items.isEmpty else { return }
        isScanning = true
        progressText = "正在清理…"

        let summary = await Task.detached(priority: .userInitiated) {
            Cleaner.clean(items)
        }.value

        removeCleaned(items)
        progressText = "清理完成"
        lastMessage = "已清理 \(summary.itemCount) 项，释放 \(summary.freedText)"
        if !summary.failedPaths.isEmpty {
            lastError = "有 \(summary.failedPaths.count) 项未能清理（可能正被占用）"
        }
        isScanning = false
    }

    func scanOffice() async {
        guard !isScanning else { return }
        isScanning = true
        progressText = "正在扫描办公软件…"
        lastError = nil

        let groups = await Task.detached(priority: .userInitiated) {
            OfficeCleaner.scan()
        }.value

        officeGroups = groups
        progressText = "扫描完成"
        isScanning = false
    }

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

    func reset() {
        dailyGroups = []
        residueGroups = []
        lastMessage = nil
        lastError = nil
        progressText = "准备就绪"
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
        for officeIndex in officeGroups.indices {
            for branchIndex in officeGroups[officeIndex].branches.indices
            where officeGroups[officeIndex].branches[branchIndex].id == groupID {
                let items = officeGroups[officeIndex].branches[branchIndex].items
                let allSelected = items.allSatisfy(\.isSelected)
                for itemIndex in officeGroups[officeIndex].branches[branchIndex].items.indices {
                    officeGroups[officeIndex].branches[branchIndex].items[itemIndex].isSelected = !allSelected
                }
                return
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
                      items: group.items.filter { !cleanedIDs.contains($0.id) })
        }.filter { !$0.items.isEmpty }
        residueGroups = residueGroups.map { group in
            ScanGroup(id: group.id, title: group.title, icon: group.icon, detail: group.detail,
                      items: group.items.filter { !cleanedIDs.contains($0.id) })
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
                    appName: $0.appName, isSelected: kind.isDefaultSafe)
                }.sorted { $0.sizeBytes > $1.sizeBytes }
            )
        }
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
                detail: "已卸载应用的遗留文件",
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

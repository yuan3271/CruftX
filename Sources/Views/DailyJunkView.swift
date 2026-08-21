import SwiftUI

struct DailyJunkView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var expanded: Set<String> = []
    @State private var viewMode: ViewMode = .category
    @State private var searchText = ""

    private enum ViewMode: String, CaseIterable, Identifiable {
        case category
        case app

        var id: String { rawValue }

        var title: String {
            switch self {
            case .category: return L10n.tr("view_by_category", default: "按分类")
            case .app: return L10n.tr("view_by_app", default: "按应用")
            }
        }

        var icon: String {
            switch self {
            case .category: return "square.grid.2x2"
            case .app: return "app.badge"
            }
        }
    }

    private var sourceGroups: [ScanGroup] {
        switch viewMode {
        case .category: return store.dailyGroups
        case .app: return store.dailyGroupsByApp
        }
    }

    private var visibleGroups: [ScanGroup] {
        guard !searchText.isEmpty else { return sourceGroups }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sourceGroups }
        return sourceGroups.compactMap { group in
            let items = group.items.filter { JunkSearch.matches($0, query: query) }
            guard !items.isEmpty else { return nil }
            return ScanGroup(
                id: group.id,
                title: group.title,
                icon: group.icon,
                detail: group.detail,
                subtitle: group.subtitle,
                items: items
            )
        }
    }

    private var totalItemCount: Int {
        store.dailyGroups.flatMap(\.items).count
    }

    private var totalBytes: Int64 {
        store.dailyGroups.reduce(0) { $0 + $1.totalBytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.isScanning {
                Spacer()
                ProgressView(store.progressText)
                Spacer()
            } else if store.dailyGroups.isEmpty {
                EmptyStateView(
                    icon: "trash.slash",
                    title: store.hasScanned
                        ? L10n.tr("daily_empty_none", default: "没有发现日常垃圾")
                        : L10n.tr("daily_empty_not_scanned", default: "尚未扫描"),
                    message: store.hasScanned
                        ? L10n.tr("daily_empty_none_msg", default: "日常目录很干净，或者已经被清理。")
                        : L10n.tr("daily_empty_scan_msg", default: "点击右上角「扫描」检查缓存、日志、临时文件与办公软件缓存。\n默认只勾选低风险内容，其余请自行决定。")
                )
            } else if visibleGroups.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: L10n.tr("no_search_results", default: "没有找到匹配项"),
                    message: L10n.tr("no_search_results_msg", default: "换个关键词试试，例如应用名、文件夹名或路径。")
                )
            } else {
                branchList
            }
        }
        .navigationTitle(L10n.tr("daily_junk", default: "日常垃圾"))
        .toolbar { scanToolbarButton }
    }

    private var branchList: some View {
        List {
            ForEach(visibleGroups) { group in
                DisclosureGroup(isExpanded: expandedBinding(group.id)) {
                    ForEach(group.items) { item in
                        BranchItemRow(item: item) {
                            store.toggleSelection(item.id)
                        }
                    }
                } label: {
                    BranchHeader(
                        icon: group.icon,
                        title: group.title,
                        detail: group.detail,
                        tint: tint(for: group),
                        selectedCount: group.items.filter(\.isSelected).count,
                        totalCount: group.items.count,
                        sizeText: group.sizeText,
                        risk: group.maxRisk
                    ) {
                        store.toggleGroup(group.id)
                    }
                }
            }
        }
        .listStyle(.bordered)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.dailyGroups.isEmpty
                         ? L10n.tr("daily_junk", default: "日常垃圾")
                         : L10n.tr("daily_found", default: "找到 %d 项", totalItemCount))
                        .font(.headline)
                    if !store.dailyGroups.isEmpty {
                        Text(L10n.tr("daily_total_note", default: "共 %@，默认只勾选低风险内容", totalBytes.fileSizeText))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Picker("", selection: $viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)

                TextField(L10n.tr("search_junk", default: "搜索名称、路径或应用"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)

                Button(L10n.tr("select_all", default: "全选")) { store.selectAllDaily(true) }
                    .disabled(store.dailyGroups.isEmpty)
                Button(L10n.tr("deselect_all", default: "取消全选")) { store.selectAllDaily(false) }
                    .disabled(store.dailyGroups.isEmpty)

                Button {
                    Task { await store.clean(store.dailyGroups.flatMap(\.items).filter(\.isSelected)) }
                } label: {
                    Label(L10n.tr("clean_selected", default: "清理选中"), systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.dailyGroups.isEmpty || store.isScanning || store.dailySelectedBytes == 0)
            }

            riskLegend
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var riskLegend: some View {
        HStack(spacing: 14) {
            ForEach(CleanupRisk.allCases, id: \.self) { risk in
                Label(risk.title, systemImage: risk.icon)
                    .font(.caption)
                    .foregroundStyle(risk.color)
            }
            Text(L10n.tr("risk_default_hint", default: "低风险内容默认勾选，中高风险需手动确认"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func tint(for group: ScanGroup) -> Color {
        switch group.id {
        case JunkKind.caches.rawValue: return .blue
        case JunkKind.logs.rawValue: return .teal
        case JunkKind.diagnosticReports.rawValue: return .orange
        case JunkKind.derivedData.rawValue: return .indigo
        case JunkKind.tempFiles.rawValue: return .gray
        case "officeCache": return .cyan
        default: return .blue
        }
    }

    private func expandedBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expanded.insert(id)
                } else {
                    expanded.remove(id)
                }
            }
        )
    }

    private var scanToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await store.startScan() }
            } label: {
                Label(L10n.tr("start_scan", default: "扫描"), systemImage: "arrow.clockwise")
            }
            .disabled(store.isScanning)
        }
    }
}

struct ResidueView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var expanded: Set<String> = []
    @State private var showIgnoredSheet = false
    @State private var searchText = ""

    private var visibleActiveGroups: [ScanGroup] {
        filterGroups(store.residueGroups)
    }

    private var visibleIgnoredGroups: [ScanGroup] {
        filterGroups(store.ignoredResidueGroups)
    }

    private func filterGroups(_ groups: [ScanGroup]) -> [ScanGroup] {
        guard !searchText.isEmpty else { return groups }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            let items = group.items.filter { JunkSearch.matches($0, query: query) }
            guard !items.isEmpty else { return nil }
            return ScanGroup(
                id: group.id,
                title: group.title,
                icon: group.icon,
                detail: group.detail,
                subtitle: group.subtitle,
                items: items
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.isScanning {
                Spacer()
                ProgressView(store.progressText)
                Spacer()
            } else if !store.hasScanned && store.residueGroups.isEmpty {
                EmptyStateView(
                    icon: "square.grid.2x2",
                    title: L10n.tr("residue_empty_not_scanned", default: "尚未扫描"),
                    message: L10n.tr("residue_empty_scan_msg", default: "点击右上角「扫描」检查应用支持文件、容器、偏好设置等残留。\n残留默认不勾选，确认后再手动选择。")
                )
            } else if store.residueGroups.isEmpty && store.ignoredResidueGroups.isEmpty {
                EmptyStateView(
                    icon: "square.grid.2x2",
                    title: L10n.tr("residue_empty_none", default: "没有发现卸载残留"),
                    message: L10n.tr("residue_empty_none_msg", default: "未找到已卸载应用留下的文件。")
                )
            } else if visibleActiveGroups.isEmpty && visibleIgnoredGroups.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: L10n.tr("no_search_results", default: "没有找到匹配项"),
                    message: L10n.tr("no_search_results_msg", default: "换个关键词试试，例如应用名、文件夹名或路径。")
                )
            } else {
                residueList
            }
        }
        .navigationTitle(L10n.tr("uninstall_residue", default: "卸载残留"))
        .toolbar { scanToolbarButton }
        .sheet(isPresented: $showIgnoredSheet) {
            ManageIgnoredView()
                .environmentObject(store)
        }
    }

    private var residueList: some View {
        List {
            if !visibleActiveGroups.isEmpty {
                Section(L10n.tr("not_ignored", default: "未忽略")) {
                    ForEach(visibleActiveGroups) { group in
                        residueGroup(group, ignored: false)
                    }
                }
            }
            if !visibleIgnoredGroups.isEmpty {
                Section(L10n.tr("temporarily_ignored", default: "暂时忽略")) {
                    ForEach(visibleIgnoredGroups) { group in
                        residueGroup(group, ignored: true)
                    }
                }
            }
        }
        .listStyle(.bordered)
    }

    private func residueGroup(_ group: ScanGroup, ignored: Bool) -> some View {
        DisclosureGroup(isExpanded: expandedBinding(group.id + (ignored ? "-ignored" : ""))) {
            ForEach(group.items) { item in
                BranchItemRow(
                    item: item,
                    onToggle: { store.toggleSelection(item.id) },
                    onIgnoreTemporary: ignored ? nil : {
                        store.ignoreResidue([item], kind: .temporary)
                    },
                    onIgnorePermanent: ignored ? nil : {
                        store.ignoreResidue([item], kind: .permanent)
                    }
                )
                .contextMenu {
                    if ignored {
                        Button {
                            store.unignoreResidue([item])
                        } label: {
                            Label(L10n.tr("unignore", default: "取消忽略"), systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
        } label: {
            BranchHeader(
                icon: group.icon,
                title: group.title,
                detail: ignored
                    ? L10n.tr("temporarily_ignored", default: "暂时忽略")
                    : (group.subtitle ?? L10n.tr("residue_leftover_detail", default: "已卸载应用的遗留文件")),
                tint: ignored ? .gray : .orange,
                selectedCount: group.items.filter(\.isSelected).count,
                totalCount: group.items.count,
                sizeText: group.sizeText,
                risk: ignored ? nil : group.maxRisk
            ) {
                store.toggleGroup(group.id)
            }
            .contextMenu {
                if ignored {
                    Button {
                        store.unignoreResidue(group.items)
                    } label: {
                        Label(L10n.tr("unignore", default: "取消忽略"), systemImage: "arrow.uturn.backward")
                    }
                } else {
                    Button {
                        store.ignoreResidue(group.items, kind: .temporary)
                    } label: {
                        Label(L10n.tr("ignore_7d", default: "暂时忽略 7 天"), systemImage: "clock.badge.questionmark")
                    }
                    Button {
                        store.ignoreResidue(group.items, kind: .permanent)
                    } label: {
                        Label(L10n.tr("ignore_forever", default: "永久忽略"), systemImage: "eye.slash")
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.residueGroups.isEmpty
                         ? L10n.tr("uninstall_residue", default: "卸载残留")
                         : L10n.tr("residue_apps_with_files", default: "%d 个应用留有文件", store.residueGroups.count))
                        .font(.headline)
                    if !store.residueGroups.isEmpty {
                        Text(L10n.tr("residue_total_note", default: "共 %@，请先确认再勾选", store.residueGroups.reduce(0) { $0 + $1.totalBytes }.fileSizeText))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                TextField(L10n.tr("search_residue", default: "搜索名称、路径或应用"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)

                Button(L10n.tr("manage_ignored", default: "已忽略管理")) {
                    showIgnoredSheet = true
                }

                Button(L10n.tr("select_all", default: "全选")) { store.selectAllResidue(true) }
                    .disabled(store.residueGroups.isEmpty)
                Button(L10n.tr("deselect_all", default: "取消全选")) { store.selectAllResidue(false) }
                    .disabled(store.residueGroups.isEmpty)

                Button {
                    Task { await store.clean(store.residueGroups.flatMap(\.items).filter(\.isSelected)) }
                } label: {
                    Label(L10n.tr("clean_selected", default: "清理选中"), systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.residueGroups.isEmpty || store.isScanning || store.residueSelectedBytes == 0)
            }

            Label(
                L10n.tr("residue_warning_banner", default: "卸载残留采用启发式识别，可能误判；全部默认为高风险且不勾选，请逐项确认后再清理。"),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func expandedBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expanded.insert(id)
                } else {
                    expanded.remove(id)
                }
            }
        )
    }

    private var scanToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await store.startScan() }
            } label: {
                Label(L10n.tr("start_scan", default: "扫描"), systemImage: "arrow.clockwise")
            }
            .disabled(store.isScanning)
        }
    }
}

struct ManageIgnoredView: View {
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [IgnoreManager.Entry] = IgnoreManager.listIgnored()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.tr("manage_ignored", default: "已忽略管理"))
                    .font(.headline)
                Spacer()
                Button(L10n.tr("cancel", default: "取消")) { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding(16)
            Divider()

            if entries.isEmpty {
                EmptyStateView(
                    icon: "eye",
                    title: L10n.tr("no_ignored_items", default: "暂无已忽略项"),
                    message: ""
                )
            } else {
                List(entries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.kind == .permanent ? "eye.slash" : "clock")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text((entry.path as NSString).lastPathComponent)
                                .lineLimit(1)
                            Text(entry.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(L10n.tr("unignore", default: "取消忽略")) {
                            store.unignore(path: entry.path)
                            entries = IgnoreManager.listIgnored()
                        }
                    }
                }
                .listStyle(.bordered)
            }
        }
        .frame(width: 520, height: 420)
    }
}

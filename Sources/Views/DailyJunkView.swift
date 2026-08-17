import SwiftUI

struct DailyJunkView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var expanded: Set<String> = []

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
                    title: store.hasScanned ? "没有发现日常垃圾" : "尚未扫描",
                    message: store.hasScanned
                        ? "日常目录很干净，或者已经被清理。"
                        : "点击右上角「扫描」检查缓存、日志与临时文件。\n默认只勾选安全项，大项请自行决定。"
                )
            } else {
                branchList(groups: store.dailyGroups)
            }
        }
        .navigationTitle("日常垃圾")
        .toolbar { scanToolbarButton }
    }

    private func branchList(groups: [ScanGroup]) -> some View {
        List {
            ForEach(groups) { group in
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
                        tint: tint(for: group.id),
                        selectedCount: group.items.filter(\.isSelected).count,
                        totalCount: group.items.count,
                        sizeText: group.sizeText
                    ) {
                        store.toggleGroup(group.id)
                    }
                }
            }
        }
        .listStyle(.bordered)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.dailyGroups.isEmpty ? "日常垃圾" : "找到 \(store.dailyGroups.flatMap(\.items).count) 项")
                    .font(.headline)
                if !store.dailyGroups.isEmpty {
                    Text("共 \(store.dailyGroups.reduce(0) { $0 + $1.totalBytes }.fileSizeText)，默认只勾选安全项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("全选") { store.selectAllDaily(true) }
                .disabled(store.dailyGroups.isEmpty)
            Button("取消全选") { store.selectAllDaily(false) }
                .disabled(store.dailyGroups.isEmpty)

            Button {
                Task { await store.clean(store.dailyGroups.flatMap(\.items).filter(\.isSelected)) }
            } label: {
                Label("清理选中", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.dailyGroups.isEmpty || store.isScanning || store.dailySelectedBytes == 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func tint(for groupID: String) -> Color {
        switch groupID {
        case JunkKind.caches.rawValue: return .blue
        case JunkKind.logs.rawValue: return .teal
        case JunkKind.diagnosticReports.rawValue: return .orange
        case JunkKind.derivedData.rawValue: return .indigo
        case JunkKind.tempFiles.rawValue: return .gray
        default: return .gray
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
                Label("扫描", systemImage: "arrow.clockwise")
            }
            .disabled(store.isScanning)
        }
    }
}

struct ResidueView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.isScanning {
                Spacer()
                ProgressView(store.progressText)
                Spacer()
            } else if store.residueGroups.isEmpty {
                EmptyStateView(
                    icon: "square.grid.2x2",
                    title: store.hasScanned ? "没有发现卸载残留" : "尚未扫描",
                    message: store.hasScanned
                        ? "未找到已卸载应用留下的文件。"
                        : "点击右上角「扫描」检查应用支持文件、偏好设置等残留。\n残留默认不勾选，确认后再手动选择。"
                )
            } else {
                List {
                    ForEach(store.residueGroups) { group in
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
                                detail: group.subtitle ?? "已卸载应用的遗留文件",
                                tint: .orange,
                                selectedCount: group.items.filter(\.isSelected).count,
                                totalCount: group.items.count,
                                sizeText: group.sizeText
                            ) {
                                store.toggleGroup(group.id)
                            }
                        }
                    }
                }
                .listStyle(.bordered)
            }
        }
        .navigationTitle("卸载残留")
        .toolbar { scanToolbarButton }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.residueGroups.isEmpty ? "卸载残留" : "\(store.residueGroups.count) 个应用留有文件")
                    .font(.headline)
                if !store.residueGroups.isEmpty {
                    Text("共 \(store.residueGroups.reduce(0) { $0 + $1.totalBytes }.fileSizeText)，请先确认再勾选")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("全选") { store.selectAllResidue(true) }
                .disabled(store.residueGroups.isEmpty)
            Button("取消全选") { store.selectAllResidue(false) }
                .disabled(store.residueGroups.isEmpty)

            Button {
                Task { await store.clean(store.residueGroups.flatMap(\.items).filter(\.isSelected)) }
            } label: {
                Label("清理选中", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.residueGroups.isEmpty || store.isScanning || store.residueSelectedBytes == 0)
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
                Label("扫描", systemImage: "arrow.clockwise")
            }
            .disabled(store.isScanning)
        }
    }
}

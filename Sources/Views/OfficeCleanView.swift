import SwiftUI

struct OfficeCleanView: View {
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
            } else if store.officeGroups.isEmpty {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: store.officeGroups.isEmpty && store.hasScanned
                        ? L10n.tr("office_empty_none", default: "没有发现办公软件缓存")
                        : L10n.tr("office_empty_not_scanned", default: "办公软件专清"),
                    message: L10n.tr("office_empty_msg", default: "点击「扫描」检查微信、企业微信、QQ、钉钉、飞书、腾讯会议的缓存。\n微信只扫描文件缓存，聊天记录永远不会被扫描或删除。")
                )
            } else {
                List {
                    ForEach(store.officeGroups) { appGroup in
                        Section {
                            ForEach(appGroup.branches) { branch in
                                DisclosureGroup(isExpanded: expandedBinding(branch.id)) {
                                    ForEach(branch.items) { item in
                                        BranchItemRow(item: item) {
                                            store.toggleSelection(item.id)
                                        }
                                    }
                                } label: {
                                    BranchHeader(
                                        icon: branch.icon,
                                        title: branch.title,
                                        detail: nil,
                                        tint: .cyan,
                                        selectedCount: branch.items.filter(\.isSelected).count,
                                        totalCount: branch.items.count,
                                        sizeText: branch.sizeText
                                    ) {
                                        store.toggleGroup(branch.id)
                                    }
                                }
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Image(systemName: "app.dashed")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(appGroup.appName)
                                        .font(.headline)
                                    if let bundleID = appGroup.bundleID {
                                        Text(bundleID)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(appGroup.itemCount) 项 · \(appGroup.sizeText)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.bordered)
            }
        }
        .navigationTitle(L10n.tr("office_clean", default: "办公专清"))
        .toolbar { scanToolbarButton }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.officeGroups.isEmpty
                         ? L10n.tr("office_clean", default: "办公专清")
                         : L10n.tr("office_total", default: "%d 个应用，共 %@", store.officeGroups.count, store.officeTotalBytes.fileSizeText))
                        .font(.headline)
                    Text(L10n.tr("office_default_note", default: "默认不勾选，确认每一项后再清理"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await store.scanOffice() }
                } label: {
                    Label(L10n.tr("start_scan", default: "扫描"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isScanning)

                Button {
                    Task { await store.clean(store.officeGroups.flatMap(\.branches).flatMap(\.items).filter(\.isSelected)) }
                } label: {
                    Label(L10n.tr("clean_selected", default: "清理选中"), systemImage: "trash")
                }
                .disabled(store.officeGroups.isEmpty || store.isScanning || store.officeGroups.flatMap(\.branches).flatMap(\.items).filter(\.isSelected).isEmpty)
            }

            Label(
                L10n.tr("office_banner", default: "微信专清只处理图片/视频/文件缓存与临时文件；聊天记录数据库（db_storage）永远不会被扫描或删除。"),
                systemImage: "shield.checkered"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
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
                Task { await store.scanOffice() }
            } label: {
                Label(L10n.tr("start_scan", default: "扫描"), systemImage: "arrow.clockwise")
            }
            .disabled(store.isScanning)
        }
    }
}

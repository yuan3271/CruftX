import SwiftUI

struct RecycleBinView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var entryToDelete: RecycleBin.Entry?
    @State private var confirmEmpty = false

    private var totalBytes: Int64 {
        store.recycleEntries.reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.recycleEntries.isEmpty {
                EmptyStateView(
                    icon: "arrow.uturn.backward.circle",
                    title: L10n.tr("recycle_empty", default: "回收站是空的"),
                    message: L10n.tr("recycle_note", default: "清理时选择「CruftX 回收站」的文件会保存在这里，可还原或永久删除。")
                )
            } else {
                List(store.recycleEntries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: "doc")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .lineLimit(1)
                            Text(entry.originalPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(entry.movedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Text(entry.sizeBytes.fileSizeText)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Button(L10n.tr("restore", default: "还原")) {
                            store.restoreRecycleEntry(entry)
                        }
                        .buttonStyle(.bordered)

                        Button(L10n.tr("delete_permanently", default: "永久删除"), role: .destructive) {
                            entryToDelete = entry
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.bordered)
            }
        }
        .navigationTitle(L10n.tr("recycle_bin", default: "回收站"))
        .onAppear { store.refreshRecycleBin() }
        .confirmationDialog(
            entryToDelete.map { L10n.tr("recycle_confirm_delete", default: "确定永久删除「%@」？此操作不可撤销。", $0.name) } ?? "",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.tr("delete_permanently", default: "永久删除"), role: .destructive) {
                if let entry = entryToDelete {
                    store.deleteRecycleEntry(entry)
                }
                entryToDelete = nil
            }
            Button(L10n.tr("cancel", default: "取消"), role: .cancel) {
                entryToDelete = nil
            }
        }
        .confirmationDialog(
            L10n.tr("recycle_confirm_empty", default: "确定清空回收站？所有文件将被永久删除。"),
            isPresented: $confirmEmpty,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("empty_recycle", default: "清空回收站"), role: .destructive) {
                store.emptyRecycleBin()
            }
            Button(L10n.tr("cancel", default: "取消"), role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("recycle_bin", default: "回收站"))
                    .font(.headline)
                if !store.recycleEntries.isEmpty {
                    Text(L10n.tr("items_short", default: "%d 项", store.recycleEntries.count) + " · " + totalBytes.fileSizeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(L10n.tr("empty_recycle", default: "清空回收站"), role: .destructive) {
                confirmEmpty = true
            }
            .disabled(store.recycleEntries.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}

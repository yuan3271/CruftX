import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ScanStore
    @Binding var selection: AppSection?

    private var ringProgress: Double {
        let cap: Int64 = 10_000_000_000
        return Double(min(store.totalBytes, cap)) / Double(cap)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerCard

                if let update = store.updateInfo {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.blue)
                        Text(L10n.tr("update_available", default: "发现新版本 v%@", update.version))
                            .font(.callout)
                        Spacer()
                        Button(L10n.tr("view_details", default: "查看详情")) {
                            selection = .settings
                        }
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 24)
                }

                if store.lastError != nil {
                    StatusBanner(message: store.lastError, isError: true)
                } else if store.lastMessage != nil {
                    StatusBanner(message: store.lastMessage, isError: false)
                }

                if store.isScanning {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(store.progressText)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                }

                if store.hasScanned {
                    statsSection
                } else if !store.isScanning {
                    EmptyStateView(
                        icon: "sparkles",
                        title: L10n.tr("empty_dashboard_title", default: "扫描你的 Mac"),
                        message: L10n.tr("empty_dashboard_message", default: "点击「开始扫描」检查日常垃圾与卸载残留。\n所有清理都会先移入废纸篓，随时可以恢复。")
                    )
                    .frame(minHeight: 260)
                }
            }
            .padding(.vertical, 24)
        }
        .navigationTitle(L10n.tr("dashboard", default: "概览"))
        .toolbar { scanToolbarButton }
    }

    private var headerCard: some View {
        HStack(spacing: 28) {
            ProgressRingView(progress: ringProgress, size: 150, lineWidth: 14)
                .overlay {
                    VStack(spacing: 2) {
                        Text(store.hasScanned ? store.totalSizeText : "—")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(L10n.tr("reclaimable", default: "可清理"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                Text("CruftX")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(store.hasScanned
                     ? L10n.tr("found_items", default: "找到 %d 项可清理内容", store.itemCount)
                     : L10n.tr("keep_mac_clean", default: "让 Mac 保持清爽"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        Task { await store.startScan() }
                    } label: {
                        Label(store.isScanning
                              ? L10n.tr("scanning_short", default: "扫描中…")
                              : L10n.tr("start_scan", default: "开始扫描"),
                              systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isScanning)

                    Button {
                        selection = .dailyJunk
                    } label: {
                        Label(L10n.tr("view_details", default: "查看详情"), systemImage: "list.bullet")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!store.hasScanned)
                }
            }
            Spacer()
        }
        .padding(28)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.14), Color.cyan.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .padding(.horizontal, 24)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("scan_results", default: "扫描结果"))
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                StatCard(
                    icon: "trash",
                    title: L10n.tr("daily_junk", default: "日常垃圾"),
                    value: store.dailyGroups.reduce(0) { $0 + $1.totalBytes }.fileSizeText,
                    tint: .blue
                )
                StatCard(
                    icon: "app.dashed",
                    title: L10n.tr("uninstall_residue", default: "卸载残留"),
                    value: L10n.tr("app_detail_plural", default: "%d 个应用", store.residueGroups.count),
                    tint: .orange
                )
                StatCard(
                    icon: "checkmark.seal",
                    title: L10n.tr("scan_item", default: "扫描项目"),
                    value: L10n.tr("items_short", default: "%d 项", store.itemCount),
                    tint: .green
                )
            }
            .padding(.horizontal, 24)
        }
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

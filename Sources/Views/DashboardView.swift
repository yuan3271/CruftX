import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ScanStore

    private var ringProgress: Double {
        let cap: Int64 = 10_000_000_000
        return Double(min(store.totalBytes, cap)) / Double(cap)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerCard

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
                        title: "扫描你的 Mac",
                        message: "点击「开始扫描」检查日常垃圾与卸载残留。\n所有清理都会先移入废纸篓，随时可以恢复。"
                    )
                    .frame(minHeight: 260)
                }
            }
            .padding(.vertical, 24)
        }
        .navigationTitle("概览")
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
                        Text("可清理")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                Text("CruftX")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(store.hasScanned
                     ? "找到 \(store.itemCount) 项可清理内容"
                     : "让 Mac 保持清爽")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        Task { await store.startScan() }
                    } label: {
                        Label(store.isScanning ? "扫描中…" : "开始扫描",
                              systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isScanning)

                    Button {
                        Task { await store.clean(store.allItems.filter(\.isSelected)) }
                    } label: {
                        Label("清理全部", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!store.hasScanned || store.isScanning)
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
            Text("扫描结果")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                StatCard(
                    icon: "trash",
                    title: "日常垃圾",
                    value: store.dailyGroups.reduce(0) { $0 + $1.totalBytes }.fileSizeText,
                    tint: .blue
                )
                StatCard(
                    icon: "app.dashed",
                    title: "卸载残留",
                    value: "\(store.residueGroups.count) 个应用",
                    tint: .orange
                )
                StatCard(
                    icon: "checkmark.seal",
                    title: "扫描项目",
                    value: "\(store.itemCount) 项",
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
                Label("扫描", systemImage: "arrow.clockwise")
            }
            .disabled(store.isScanning)
        }
    }
}

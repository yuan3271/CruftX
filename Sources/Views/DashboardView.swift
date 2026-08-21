import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ScanStore
    @Binding var selection: AppSection?

    private var ringProgress: Double {
        let cap: Int64 = 10_000_000_000
        return Double(min(store.totalBytes, cap)) / Double(cap)
    }

    private var appCount: Int {
        store.residueGroups.count
            + store.dailyGroupsByApp.filter { $0.id != "app-system-other" }.count
    }

    private var categoryRows: [(group: ScanGroup, section: AppSection, tint: Color)] {
        let daily = store.dailyGroups.map { ($0, AppSection.dailyJunk, tint(for: $0.id)) }
        let residue = store.residueGroups.map { ($0, AppSection.uninstallResidue, Color.orange) }
        return daily + residue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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

                if !store.accessIssues.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.rectangle.stack.fill")
                            .foregroundStyle(.orange)
                        Text(L10n.tr(
                            "access_issue_message",
                            default: "部分目录无法读取，扫描与清理结果可能不完整。请在「系统设置 → 隐私与安全性 → 完全磁盘访问权限」中允许 CruftX。"
                        ))
                        .font(.callout)
                        Spacer()
                        Button(L10n.tr("grant_full_disk_access_short", default: "前往授权")) {
                            Permissions.openFullDiskAccessSettings()
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    statsGrid
                    riskSection
                    categorySection
                } else if !store.isScanning {
                    emptyState
                }
            }
            .padding(.vertical, 24)
        }
        .navigationTitle(L10n.tr("dashboard", default: "概览"))
        .toolbar { scanToolbarButton }
    }

    // MARK: - Hero

    private var headerCard: some View {
        HStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 176, height: 176)
                ProgressRingView(progress: ringProgress, size: 150, lineWidth: 13)
                    .overlay {
                        VStack(spacing: 2) {
                            Text(store.hasScanned ? store.totalSizeText : "—")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(L10n.tr("reclaimable", default: "可清理"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.blue)
                    Text("CruftX")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                }

                Text(store.hasScanned
                     ? L10n.tr("found_items", default: "找到 %d 项可清理内容", store.itemCount)
                     : L10n.tr("keep_mac_clean", default: "让 Mac 保持清爽"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if store.hasScanned {
                    HStack(spacing: 16) {
                        heroMiniStat(
                            value: L10n.tr("items_short", default: "%d 项", store.itemCount),
                            label: L10n.tr("scan_item", default: "扫描项目")
                        )
                        heroMiniStat(
                            value: L10n.tr("app_detail_plural", default: "%d 个应用", appCount),
                            label: L10n.tr("apps_involved", default: "涉及应用")
                        )
                        heroMiniStat(
                            value: L10n.tr("items_short", default: "%d 项", store.highRiskCount),
                            label: L10n.tr("risk_high", default: "高风险")
                        )
                    }
                }

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
                colors: [Color.blue.opacity(0.16), Color.cyan.opacity(0.07), Color.mint.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private func heroMiniStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
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
            StatCard(
                icon: "exclamationmark.triangle",
                title: L10n.tr("risk_high", default: "高风险"),
                value: L10n.tr("items_short", default: "%d 项", store.highRiskCount),
                tint: .red
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Risk overview

    private var riskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("risk_overview", default: "风险概览"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(L10n.tr("risk_default_hint", default: "低风险内容默认勾选，中高风险需手动确认"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                riskCard(.low, bytes: store.lowRiskBytes, count: store.lowRiskCount)
                riskCard(.medium, bytes: store.mediumRiskBytes, count: store.mediumRiskCount)
                riskCard(.high, bytes: store.highRiskBytes, count: store.highRiskCount)
            }
        }
        .padding(.horizontal, 24)
    }

    private func riskCard(_ risk: CleanupRisk, bytes: Int64, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: risk.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(risk.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(bytes.fileSizeText)
                    .font(.callout.monospacedDigit())
                    .fontWeight(.semibold)
            }
            Text(L10n.tr("items_short", default: "%d 项", count))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(risk.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(risk.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(risk.color.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Category breakdown

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("scan_results", default: "扫描结果"))
                .font(.title3.weight(.semibold))

            VStack(spacing: 0) {
                ForEach(Array(categoryRows.enumerated()), id: \.element.group.id) { pair in
                    let row = pair.element
                    Button {
                        selection = row.section
                    } label: {
                        categoryRow(row)
                    }
                    .buttonStyle(.plain)
                    if pair.offset < categoryRows.count - 1 {
                        Divider()
                    }
                }
            }
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 24)
    }

    private func categoryRow(_ row: (group: ScanGroup, section: AppSection, tint: Color)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.group.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(row.tint)
                .frame(width: 30, height: 30)
                .background(row.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.group.title)
                        .font(.body.weight(.medium))
                    RiskBadge(risk: row.group.maxRisk, compact: true)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(row.tint.opacity(0.75))
                            .frame(width: geo.size.width * progress(row.group))
                    }
                }
                .frame(height: 5)

                Text(L10n.tr("items_short", default: "%d 项", row.group.items.count))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(row.group.sizeText)
                    .font(.callout.monospacedDigit())
                    .fontWeight(.semibold)
                Label(L10n.tr("view_details", default: "查看详情"), systemImage: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    private func progress(_ group: ScanGroup) -> Double {
        guard store.totalBytes > 0 else { return 0 }
        return Double(group.totalBytes) / Double(store.totalBytes)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.16), .mint.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                Image(systemName: "sparkles")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(.blue)
            }

            Text(L10n.tr("empty_dashboard_title", default: "扫描你的 Mac"))
                .font(.title2.weight(.semibold))
            Text(L10n.tr("empty_dashboard_message", default: "点击「开始扫描」检查日常垃圾、办公软件缓存与卸载残留。\n所有清理都会先移入废纸篓或回收站，随时可以恢复。"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await store.startScan() }
            } label: {
                Label(L10n.tr("start_scan", default: "开始扫描"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func tint(for groupID: String) -> Color {
        switch groupID {
        case JunkKind.caches.rawValue: return .blue
        case JunkKind.logs.rawValue: return .teal
        case JunkKind.diagnosticReports.rawValue: return .orange
        case JunkKind.derivedData.rawValue: return .indigo
        case JunkKind.tempFiles.rawValue: return .gray
        case "officeCache": return .cyan
        default: return .blue
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

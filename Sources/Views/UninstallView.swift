import AppKit
import SwiftUI

struct UninstallView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var searchText = ""
    @State private var appToUninstall: InstalledAppInfo?
    @State private var includeData = false
    @State private var relatedItems: [AppUninstaller.RelatedItem] = []
    @State private var isComputingRelated = false
    @State private var summary: CleanSummary?
    @State private var showSummary = false

    private var filteredApps: [InstalledAppInfo] {
        guard !searchText.isEmpty else { return store.installedApps }
        return store.installedApps.filter {
            JunkSearch.matches("\($0.name) \($0.bundleID ?? "") \(displayName(for: $0))", query: searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.installedApps.isEmpty {
                Spacer()
                ProgressView(L10n.tr("loading_apps", default: "正在读取已安装应用…"))
                Spacer()
            } else {
                List(filteredApps) { app in
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                            .resizable()
                            .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName(for: app))
                                .font(.body)
                            Text(app.bundleID ?? L10n.tr("unknown_bundle", default: "未知包名"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(app.sizeText)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Button(L10n.tr("uninstall", default: "卸载")) {
                            appToUninstall = app
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.bordered)
            }
        }
        .navigationTitle(L10n.tr("uninstall_app", default: "卸载应用"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.loadInstalledApps() }
                } label: {
                    Label(L10n.tr("refresh", default: "刷新"), systemImage: "arrow.clockwise")
                }
            }
        }
        .task {
            if store.installedApps.isEmpty {
                await store.loadInstalledApps()
            }
        }
        .sheet(item: $appToUninstall) { app in
            confirmSheet(app)
        }
        .alert(L10n.tr("uninstall_done", default: "卸载完成"), isPresented: $showSummary) {
            Button(L10n.tr("cancel", default: "好"), role: .cancel) {}
        } message: {
            Text(summaryMessage)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("installed_apps", default: "已安装应用"))
                    .font(.headline)
                Text(L10n.tr("uninstall_note", default: "卸载会把应用本体移入废纸篓，可随时恢复"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TextField(L10n.tr("search_apps", default: "搜索应用"), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func confirmSheet(_ app: InstalledAppInfo) -> some View {
        VStack(spacing: 16) {
            Text(L10n.tr("uninstall_title", default: "卸载 %@", app.name))
                .font(.title3.weight(.semibold))

            if isRunning(app) {
                Label(L10n.tr("running_warning", default: "该应用正在运行，建议先退出再卸载。"), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(L10n.tr("app_size_note", default: "应用本体（%@）将移入废纸篓。", app.sizeText))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(L10n.tr("include_data", default: "同时清理相关数据（缓存、偏好设置、容器等）"), isOn: $includeData)
                .toggleStyle(.checkbox)

            if includeData {
                Group {
                    if isComputingRelated {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.tr("computing_related", default: "正在计算相关数据…"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if relatedItems.isEmpty {
                        Text(L10n.tr("no_related", default: "未找到相关数据，将只卸载应用本体。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.tr("related_total", default: "将一并移入废纸篓：%d 项，共 %@", relatedItems.count, relatedItems.reduce(Int64(0)) { $0 + $1.sizeBytes }.fileSizeText))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(relatedItems.prefix(5)) { item in
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                        .font(.caption)
                                    Text(item.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.sizeBytes.fileSizeText)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            HStack {
                Button(L10n.tr("cancel", default: "取消")) {
                    appToUninstall = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(L10n.tr("move_to_trash", default: "移入废纸篓")) {
                    Task {
                        summary = await store.uninstall(app, includeData: includeData)
                        appToUninstall = nil
                        showSummary = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onChange(of: includeData) { isOn in
            if isOn {
                isComputingRelated = true
                relatedItems = []
                Task {
                    let items = await Task.detached {
                        AppUninstaller.relatedData(for: app)
                    }.value
                    relatedItems = items
                    isComputingRelated = false
                }
            } else {
                relatedItems = []
                isComputingRelated = false
            }
        }
    }

    private func isRunning(_ app: InstalledAppInfo) -> Bool {
        guard let bundleID = app.bundleID else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    private func displayName(for app: InstalledAppInfo) -> String {
        app.bundleID.flatMap(CommonApps.displayName) ?? app.name
    }

    private var summaryMessage: String {
        guard let summary else { return "" }
        var message = L10n.tr("uninstall_summary", default: "已把应用移入废纸篓")
        if summary.itemCount > 1 {
            message += L10n.tr("uninstall_summary_data", default: "及 %d 项相关数据", summary.itemCount - 1)
        }
        message += L10n.tr("freed", default: "，释放 %@。", summary.freedText)
        if !summary.failedPaths.isEmpty {
            if summary.permissionFailures > 0 {
                message += "\n" + L10n.tr(
                    "uninstall_summary_permission",
                    default: "有 %d 项因权限不足未能清理，请在「系统设置 → 隐私与安全性 → 完全磁盘访问权限」中允许 CruftX。",
                    summary.permissionFailures
                )
            } else {
                message += "\n" + L10n.tr("clean_failed", default: "有 %d 项未能清理（可能正被占用）：%@", summary.failedPaths.count, summary.failedPaths.prefix(3).joined(separator: "、"))
            }
        }
        return message
    }
}

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
            $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.bundleID?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.installedApps.isEmpty {
                Spacer()
                ProgressView("正在读取已安装应用…")
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
                            Text(app.bundleID ?? "未知包名")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(app.sizeText)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Button("卸载") {
                            appToUninstall = app
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.bordered)
            }
        }
        .navigationTitle("卸载应用")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.loadInstalledApps() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
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
        .alert("卸载完成", isPresented: $showSummary) {
            Button("好", role: .cancel) {}
        } message: {
            Text(summaryMessage)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("已安装应用")
                    .font(.headline)
                Text("卸载会把应用本体移入废纸篓，可随时恢复")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TextField("搜索应用", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func confirmSheet(_ app: InstalledAppInfo) -> some View {
        VStack(spacing: 16) {
            Text("卸载 \(app.name)")
                .font(.title3.weight(.semibold))

            if isRunning(app) {
                Label("该应用正在运行，建议先退出再卸载。", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("应用本体（\(app.sizeText)）将移入废纸篓。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("同时清理相关数据（缓存、偏好设置、容器等）", isOn: $includeData)
                .toggleStyle(.checkbox)

            if includeData {
                Group {
                    if isComputingRelated {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在计算相关数据…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if relatedItems.isEmpty {
                        Text("未找到相关数据，将只卸载应用本体。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("将一并移入废纸篓：\(relatedItems.count) 项，共 \(relatedItems.reduce(Int64(0)) { $0 + $1.sizeBytes }.fileSizeText)")
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
                Button("取消") {
                    appToUninstall = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("移入废纸篓") {
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
        var message = "已把应用移入废纸篓"
        if summary.itemCount > 1 {
            message += "及 \(summary.itemCount - 1) 项相关数据"
        }
        message += "，释放 \(summary.freedText)。"
        if !summary.failedPaths.isEmpty {
            message += "\n有 \(summary.failedPaths.count) 项未能清理（可能正被占用）：\(summary.failedPaths.prefix(3).joined(separator: "、"))"
        }
        return message
    }
}

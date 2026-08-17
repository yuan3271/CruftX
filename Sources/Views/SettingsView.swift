import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ScanStore
    @EnvironmentObject private var language: LanguageManager

    var body: some View {
        Form {
            Section(L10n.tr("daily_junk", default: "日常垃圾")) {
                Toggle(L10n.tr("junk_kind_caches", default: "应用缓存"), isOn: $store.includeCaches)
                Toggle(L10n.tr("junk_kind_logs", default: "日志文件"), isOn: $store.includeLogs)
                Toggle(L10n.tr("junk_kind_diagnostics", default: "诊断报告"), isOn: $store.includeDiagnostics)
                Toggle(L10n.tr("junk_kind_derived", default: "Xcode 派生数据"), isOn: $store.includeDerivedData)
                Toggle(L10n.tr("junk_kind_temp", default: "临时文件"), isOn: $store.includeTempFiles)
            }

            Section(L10n.tr("uninstall_residue", default: "卸载残留")) {
                Toggle(L10n.tr("residue_kind_app_support", default: "应用支持文件"), isOn: $store.includeAppSupport)
                Toggle(L10n.tr("residue_kind_prefs", default: "偏好设置"), isOn: $store.includePrefs)
                Toggle(L10n.tr("residue_kind_saved_state", default: "已保存的窗口状态"), isOn: $store.includeSavedState)
                Toggle(L10n.tr("residue_kind_http", default: "网络存储 (HTTPStorages)"), isOn: $store.includeHTTPStorage)
            }

            Section(L10n.tr("cleanup_destination", default: "清理去向")) {
                Picker(L10n.tr("cleanup_destination", default: "清理去向"), selection: $store.cleanupDestination) {
                    Text(L10n.tr("trash", default: "系统废纸篓")).tag("trash")
                    Text(L10n.tr("recycle_bin_name", default: "CruftX 回收站")).tag("recycle")
                }
                .pickerStyle(.radioGroup)
                Text(L10n.tr("recycle_note", default: "清理时选择「CruftX 回收站」的文件会保存在这里，可还原或永久删除。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.tr("language", default: "语言")) {
                Picker(L10n.tr("language", default: "语言"), selection: languageBinding) {
                    Text(L10n.tr("follow_system", default: "跟随系统")).tag("system")
                    Text(L10n.tr("chinese", default: "中文")).tag("zh-Hans")
                    Text(L10n.tr("english", default: "English")).tag("en")
                }
                .pickerStyle(.radioGroup)
            }

            Section(L10n.tr("updates", default: "更新")) {
                LabeledContent(L10n.tr("version", default: "版本"), value: UpdateChecker.currentVersion)
                if let update = store.updateInfo {
                    LabeledContent(L10n.tr("update_available", default: "发现新版本 v%@", update.version), value: "")
                    if !update.notes.isEmpty {
                        Text(update.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await store.downloadUpdate() }
                    } label: {
                        Label(store.isDownloadingUpdate
                              ? L10n.tr("downloading", default: "正在下载…")
                              : L10n.tr("download_update", default: "下载更新"),
                              systemImage: "arrow.down.circle")
                    }
                    .disabled(store.isDownloadingUpdate)
                } else if store.isCheckingUpdate {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.tr("checking", default: "正在检查…"))
                            .foregroundStyle(.secondary)
                    }
                } else if store.updateMessage == nil {
                    Text(L10n.tr("up_to_date", default: "已是最新版本"))
                        .foregroundStyle(.secondary)
                }
                if let message = store.updateMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await store.checkForUpdate(force: true) }
                } label: {
                    Label(L10n.tr("check_updates", default: "检查更新"), systemImage: "arrow.clockwise")
                }
                .disabled(store.isCheckingUpdate)
                Text(L10n.tr("update_settings_hint", default: "自动检查 GitHub Releases 新版本，下载安装镜像。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.tr("settings_about", default: "关于")) {
                LabeledContent(L10n.tr("version", default: "版本"), value: UpdateChecker.currentVersion)
                LabeledContent(L10n.tr("scan_scope", default: "扫描范围"), value: L10n.tr("current_user", default: "当前用户目录"))
                LabeledContent(
                    L10n.tr("clean_method", default: "清理方式"),
                    value: store.cleanupDestinationIsRecycle
                        ? L10n.tr("recycle_bin_name", default: "CruftX 回收站")
                        : L10n.tr("trash", default: "系统废纸篓")
                )
                Text(L10n.tr("about_text", default: "CruftX 只扫描当前用户目录下的缓存、日志与已卸载应用的遗留文件。默认只勾选安全项；残留与专清需手动确认。清理去向可在上方选择：移入系统废纸篓，或保存在 CruftX 回收站中随时还原/永久删除。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.tr("settings", default: "设置"))
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { language.languageCode },
            set: { language.setLanguage($0) }
        )
    }
}

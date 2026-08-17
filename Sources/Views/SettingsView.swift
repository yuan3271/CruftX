import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        Form {
            Section("日常垃圾") {
                Toggle("应用缓存", isOn: $store.includeCaches)
                Toggle("日志文件", isOn: $store.includeLogs)
                Toggle("诊断报告", isOn: $store.includeDiagnostics)
                Toggle("Xcode 派生数据", isOn: $store.includeDerivedData)
                Toggle("临时文件", isOn: $store.includeTempFiles)
            }

            Section("卸载残留") {
                Toggle("应用支持文件", isOn: $store.includeAppSupport)
                Toggle("偏好设置", isOn: $store.includePrefs)
                Toggle("已保存的窗口状态", isOn: $store.includeSavedState)
                Toggle("网络存储 (HTTPStorages)", isOn: $store.includeHTTPStorage)
            }

            Section("关于") {
                LabeledContent("版本", value: "1.0")
                LabeledContent("扫描范围", value: "当前用户目录")
                LabeledContent("清理方式", value: "移入废纸篓")
                Text("CruftX 只扫描当前用户目录下的缓存、日志与已卸载应用的遗留文件。默认只勾选安全项；残留与专清需手动确认。清理会先把文件移入废纸篓，误删可从废纸篓恢复。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }
}

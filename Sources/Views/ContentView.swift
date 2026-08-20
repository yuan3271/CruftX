import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var selection: AppSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            switch selection ?? .dashboard {
            case .dashboard:
                DashboardView(selection: $selection)
            case .dailyJunk:
                DailyJunkView()
            case .uninstallResidue:
                ResidueView()
            case .uninstall:
                UninstallView()
            case .recycleBin:
                RecycleBinView()
            case .settings:
                SettingsView()
            }
        }
        .background(.background)
        .task {
            await store.checkForUpdate()
        }
    }
}

struct SidebarView: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(selection: $selection) {
            Section(L10n.tr("overview", default: "概览")) {
                sidebarRow(.dashboard)
            }
            Section(L10n.tr("clean_tools", default: "清理工具")) {
                sidebarRow(.dailyJunk)
                sidebarRow(.uninstallResidue)
            }
            Section(L10n.tr("app_management", default: "应用管理")) {
                sidebarRow(.uninstall)
                sidebarRow(.recycleBin)
            }
            Section {
                sidebarRow(.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("CruftX")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Text("CruftX \(UpdateChecker.currentVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("清理前会先移入废纸篓")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private func sidebarRow(_ section: AppSection) -> some View {
        Label(section.title, systemImage: section.icon)
            .tag(section)
    }
}

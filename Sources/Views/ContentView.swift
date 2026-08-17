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
                DashboardView()
            case .dailyJunk:
                DailyJunkView()
            case .uninstallResidue:
                ResidueView()
            case .officeClean:
                OfficeCleanView()
            case .uninstall:
                UninstallView()
            case .settings:
                SettingsView()
            }
        }
        .background(.background)
    }
}

struct SidebarView: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(selection: $selection) {
            Section("概览") {
                sidebarRow(.dashboard)
            }
            Section("清理工具") {
                sidebarRow(.dailyJunk)
                sidebarRow(.uninstallResidue)
                sidebarRow(.officeClean)
            }
            Section("应用管理") {
                sidebarRow(.uninstall)
            }
            Section {
                sidebarRow(.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("CruftX")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Text("CruftX 1.0")
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

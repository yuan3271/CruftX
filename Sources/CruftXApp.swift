import SwiftUI

@main
struct CruftXApp: App {
    @StateObject private var store = ScanStore()

    init() {
        // Headless smoke test: runs the scanners and prints a summary.
        // Usage: CruftX --scan-test
        if CommandLine.arguments.contains("--scan-test") {
            let daily = JunkScanner.scanDailyJunk(kinds: Set(JunkKind.allCases))
            let residue = ResidueScanner.scanResidue(kinds: Set(ResidueKind.allCases))
            let office = OfficeCleaner.scan()
            let dailyBytes = daily.reduce(Int64(0)) { $0 + $1.sizeBytes }
            let residueBytes = residue.reduce(Int64(0)) { $0 + $1.sizeBytes }
            print("daily: \(daily.count) items, \(dailyBytes) bytes")
            for entry in daily.prefix(10) {
                print("  [\(entry.kind?.rawValue ?? "?")] \(entry.path.path) \(entry.sizeBytes)")
            }
            print("residue: \(residue.count) items, \(residueBytes) bytes")
            let byKind = Dictionary(grouping: residue) { $0.residueKind?.rawValue ?? "?" }
            for (kind, entries) in byKind.sorted(by: { $0.key < $1.key }) {
                print("  kind \(kind): \(entries.count) items, \(entries.reduce(Int64(0)) { $0 + $1.sizeBytes }) bytes")
            }
            for entry in residue.prefix(15) {
                print("  [\(entry.residueKind?.rawValue ?? "?")] \(entry.appName ?? "?") \(entry.path.lastPathComponent) \(entry.sizeBytes)")
            }
            print("office: \(office.count) apps, \(office.reduce(Int64(0)) { $0 + $1.totalBytes }) bytes")
            for group in office {
                print("  [\(group.appName)] \(group.branches.count) branches, \(group.totalBytes) bytes")
                for branch in group.branches {
                    print("    - \(branch.title): \(branch.items.count) items, \(branch.totalBytes) bytes")
                    for item in branch.items {
                        print("      \(item.path.path) \(item.sizeBytes)")
                    }
                }
            }
            let apps = AppUninstaller.scanInstalledApps()
            print("installed apps: \(apps.count)")
            for app in apps.prefix(10) {
                print("  \(app.name) (\(app.bundleID ?? "-")) \(app.sizeBytes)")
            }
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 920, minHeight: 600)
        }
        .defaultSize(width: 1080, height: 720)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {}
        }
    }
}

import AppKit
import Foundation

/// Detects and helps fix insufficient file-system permission (Full Disk
/// Access). CruftX scans the user's Library; some subfolders (Containers,
/// Group Containers and protected app data) are guarded by TCC and return
/// permission errors unless the app has Full Disk Access.
enum Permissions {

    /// The System Settings pane for Full Disk Access (macOS 13+).
    static let fullDiskAccessURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )!

    static func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(fullDiskAccessURL)
    }

    /// True when an `Error` is caused by a read/write permission denial.
    static func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain {
            // 257 = NSFileReadNoPermissionError, 513 = NSFileWriteNoPermissionError.
            if ns.code == 257 || ns.code == 513 { return true }
        }
        if isPermissionCode(ns.domain, ns.code) { return true }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionCode(underlying.domain, underlying.code)
        }
        return false
    }

    private static func isPermissionCode(_ domain: String, _ code: Int) -> Bool {
        guard domain == NSPOSIXErrorDomain else { return false }
        // EACCES / EPERM
        return code == 13 || code == 1
    }

    /// Returns the paths of the scan roots CruftX touches that are currently
    /// unreadable due to permissions. Used to alert the user that results may
    /// be incomplete and to offer Full Disk Access.
    static func unreadableLocations() -> [String] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let roots: [URL] = [
            home.appendingPathComponent("Library/Caches", isDirectory: true),
            home.appendingPathComponent("Library/Logs", isDirectory: true),
            home.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true),
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true),
            home.appendingPathComponent("Library/Application Support", isDirectory: true),
            home.appendingPathComponent("Library/Containers", isDirectory: true),
            home.appendingPathComponent("Library/Group Containers", isDirectory: true),
            home.appendingPathComponent("Library/Preferences", isDirectory: true),
            home.appendingPathComponent("Library/Saved Application State", isDirectory: true),
            home.appendingPathComponent("Library/HTTPStorages", isDirectory: true),
            home.appendingPathComponent("Library/Containers/com.tencent.xinWeChat/Data", isDirectory: true)
        ]

        return roots
            .filter { fm.fileExists(atPath: $0.path) }
            .compactMap { root in
                do {
                    _ = try fm.contentsOfDirectory(
                        at: root,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                    return nil
                } catch {
                    return isPermissionError(error) ? root.path : nil
                }
            }
    }
}

import Foundation

/// Checks GitHub Releases for a newer CruftX version.
struct UpdateInfo: Sendable {
    let version: String
    let notes: String
    let downloadURL: URL
}

enum UpdateChecker {
    static let repository = "yuan3271/CruftX"

    private struct Release: Decodable {
        let tag_name: String
        let body: String?
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: String
    }

    /// Returns the latest release if it is newer than the running app.
    static func checkLatest() async throws -> UpdateInfo? {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CruftX/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        let release = try JSONDecoder().decode(Release.self, from: data)
        let version = release.tag_name.replacingOccurrences(of: "v", with: "")
        guard isNewer(version, than: currentVersion),
              let asset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }),
              let url = URL(string: asset.browser_download_url) else {
            return nil
        }
        return UpdateInfo(version: version, notes: release.body ?? "", downloadURL: url)
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"
    }

    /// Downloads the update asset and reveals it in Finder.
    static func download(_ info: UpdateInfo) async throws -> URL {
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let destination = downloads
            .appendingPathComponent("CruftX-\(info.version).dmg")

        let (tempURL, _) = try await URLSession.shared.download(from: info.downloadURL)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parse(candidate)
        let b = parse(current)
        for i in 0..<max(a.count, b.count) {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }

    private static func parse(_ version: String) -> [Int] {
        version.split(separator: ".").compactMap { Int($0) }
    }
}

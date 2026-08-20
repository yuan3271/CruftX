import Foundation

/// A built-in database of well-known bundle identifiers mapped to their
/// familiar display names. Used to show 微信 instead of "xinWeChat",
/// "Visual Studio Code" instead of "Code", and so on.
enum CommonApps {

    /// Debug/testing switch: `--scan-test-nodb` bypasses the name database.
    static var useDatabase: Bool {
        !CommandLine.arguments.contains("--scan-test-nodb")
    }

    static let database: [String: String] = [
        // 微信生态
        "com.tencent.xinWeChat": "微信",
        "com.tencent.qq": "QQ",
        "com.tencent.wework": "企业微信",
        "com.tencent.meeting": "腾讯会议",
        "com.tencent.qqmusic": "QQ音乐",
        "com.tencent.LemonMonitor": "腾讯柠檬清理",
        "com.tencent.wechat.devtools": "微信开发者工具",
        "com.tencent.tencentvideo": "腾讯视频",
        "com.tencent.WeReadMac": "微信读书",

        // 办公 / 协作
        "com.laiwang.DingTalk": "钉钉",
        "com.larksuite.suite": "飞书",
        "com.microsoft.Word": "Microsoft Word",
        "com.microsoft.Excel": "Microsoft Excel",
        "com.microsoft.Powerpoint": "Microsoft PowerPoint",
        "com.microsoft.OneDrive": "OneDrive",
        "com.microsoft.teams": "Microsoft Teams",
        "com.microsoft.VSCode": "Visual Studio Code",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.microsoft.rdc.macos": "Microsoft Remote Desktop",
        "com.skype.skype": "Skype",
        "com.tinyspeck.slackmacgap": "Slack",
        "com.zoom.us": "Zoom",
        "us.zoom.xos": "Zoom",
        "notion.id": "Notion",
        "md.obsidian": "Obsidian",
        "com.sublimetext.4": "Sublime Text",
        "com.sublimetext.3": "Sublime Text",
        "com.apple.dt.Xcode": "Xcode",
        "com.google.android.studio": "Android Studio",
        "com.jetbrains.intellij": "IntelliJ IDEA",
        "com.jetbrains.idea": "IntelliJ IDEA",
        "com.jetbrains.pycharm": "PyCharm",
        "com.jetbrains.goland": "GoLand",
        "com.jetbrains.webstorm": "WebStorm",
        "com.jetbrains.clion": "CLion",
        "com.jetbrains.datagrip": "DataGrip",
        "com.jetbrains.rubymine": "RubyMine",
        "com.jetbrains.appcode": "AppCode",
        "com.googlecode.iterm2": "iTerm2",
        "com.github.GitHubClient": "GitHub Desktop",
        "com.sourcetree.mac": "Sourcetree",
        "com.figma.Desktop": "Figma",
        "com.postmanlabs.mac": "Postman",

        // 浏览器
        "com.google.Chrome": "Google Chrome",
        "com.apple.Safari": "Safari",
        "org.mozilla.firefox": "Firefox",
        "com.operasoftware.Opera": "Opera",
        "com.brave.Browser": "Brave",
        "com.arc.arc": "Arc",

        // 影音 / 娱乐
        "com.netease.CloudMusic": "网易云音乐",
        "com.spotify.client": "Spotify",
        "com.apple.Music": "音乐",
        "com.apple.TV": "Apple TV",
        "org.videolan.vlc": "VLC",
        "com.colliderli.iina": "IINA",
        "com.kugou.mac": "酷狗音乐",
        "com.bilibili.bilibiliPC": "哔哩哔哩",
        "com.xingin.discover": "小红书",
        "com.youku.YouKu": "优酷",
        "com.iqiyi.player": "爱奇艺",
        "com.netflix.Netflix": "Netflix",

        // 游戏
        "com.valvesoftware.steam": "Steam",
        "com.epicgames.EpicGamesLauncher": "Epic Games Launcher",
        "com.blizzard.Battle.net": "Battle.net",
        "com.riotgames.LeagueofLegends": "英雄联盟",
        "com.7thbeat.adofai": "A Dance of Fire and Ice",
        "com.mojang.minecraft": "Minecraft",

        // 通讯
        "com.hnc.Discord": "Discord",
        "org.whispersystems.signal-desktop": "Signal",
        "ru.keepcoder.Telegram": "Telegram",
        "com.whatsapp.mac": "WhatsApp",

        // 工具
        "com.docker.docker": "Docker",
        "com.parallels.desktop": "Parallels Desktop",
        "com.vmware.fusion": "VMware Fusion",
        "com.aone.keka": "Keka",
        "com.agilebits.onepassword7": "1Password",
        "com.1password.1password": "1Password",
        "com.macpaw.CleanMyMac4": "CleanMyMac X",
        "com.macpaw.CleanMyMac5": "CleanMyMac X",
        "org.localsend.localsendApp": "LocalSend",
        "com.codeweavers.CrossOver": "CrossOver",
        "com.pdfeditor.pdfeditormac": "PDFgear",
        "cn.com.10jqka.IHexin": "同花顺",
        "com.pixpin.PixPin": "PixPin",
        "com.obsproject.obs-studio": "OBS Studio",
        "com.adobe.Photoshop": "Adobe Photoshop",
        "com.adobe.illustrator": "Adobe Illustrator",
        "com.adobe.AfterEffects": "Adobe After Effects",
        "com.readdle.PDFExpert-macOS": "PDF Expert",
        "com.apple.iMovie": "iMovie",
        "com.apple.FinalCut": "Final Cut Pro"
    ]

    /// Exact match first, then prefix match (e.g. a helper bundle
    /// "com.tencent.xinWeChat.Helper" still resolves to 微信), then a
    /// heuristic fallback for unknown bundle IDs.
    static func displayName(for bundleID: String) -> String? {
        guard useDatabase else { return nil }
        if let exact = database[bundleID] {
            return exact
        }
        let lower = bundleID.lowercased()
        for (key, name) in database where lower.hasPrefix(key.lowercased() + ".") {
            return name
        }
        return fallbackName(for: bundleID)
    }

    /// Heuristic display name for a bundle ID or folder name, e.g.
    /// "com.example.SomeTool.Helper" -> "Some Tool".
    static func fallbackName(for bundleOrName: String) -> String {
        var components = bundleOrName.split(separator: ".").map(String.init)
        // Drop the reverse-DNS prefix, e.g. "com." / "io." / "cn.".
        if let first = components.first,
           ["com", "cn", "org", "io", "net", "me", "co", "app", "dev", "www"].contains(first.lowercased()) {
            components.removeFirst()
        }

        let genericWords: Set<String> = [
            "pro", "app", "mac", "desktop", "client", "mobile", "hd", "web",
            "helper", "agent", "service", "daemon", "extension", "today",
            "widget", "share", "main", "core", "lite", "beta", "test", "dev",
            "macos", "osx", "suite", "plugin", "appex", "xpc"
        ]

        var chosen = components.last ?? bundleOrName
        for component in components.reversed() {
            var cleaned = component
            for prefix in ["mac-", "macos-", "osx-"] where cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
            if cleaned.lowercased().hasSuffix("-mac") {
                cleaned = String(cleaned.dropLast(4))
            }
            guard !cleaned.isEmpty, !genericWords.contains(cleaned.lowercased()) else { continue }
            chosen = cleaned
            break
        }
        return splitCamelCase(chosen)
    }

    /// Infers a user-facing app name from a Library folder name, used to
    /// classify daily junk by app. Returns nil for generic or system paths.
    static func appName(fromFolderName name: String, kind: JunkKind? = nil) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(".") else { return nil }

        // Derived data and temp folders don't carry a reliable app name.
        if kind == .derivedData || kind == .tempFiles || kind == .diagnosticReports {
            return nil
        }

        // Bundle-ID folders resolve through the known-app database.
        if isBundleIDLike(trimmed), let known = displayName(for: trimmed) {
            return known
        }

        var cleaned = trimmed
        for suffix in [".app", ".savedState", ".plist", ".framework", ".bundle", ".plugin", ".appex"] where cleaned.hasSuffix(suffix) {
            cleaned = String(cleaned.dropLast(suffix.count))
        }
        guard !cleaned.isEmpty else { return nil }

        let normalized = ResidueScanner.normalize(cleaned)
        guard normalized.count >= 3 else { return nil }

        let genericTokens: Set<String> = [
            "cache", "caches", "logs", "log", "tmp", "temp", "diagnostic",
            "reports", "report", "crash", "crashpad", "metadata", "webkit",
            "system", "apple", "user", "users", "shared", "library", "updates",
            "update", "installer", "installers", "helper", "helpers", "plugins",
            "plugin", "extensions", "extension", "services", "service",
            "daemon", "daemons", "agent", "agents", "frameworks", "components",
            "tools", "tool", "bin", "core", "widgets", "fonts", "keychains",
            "containers", "preferences", "support", "app", "apps", "applications"
        ]
        guard !genericTokens.contains(normalized) else { return nil }
        // Skip if the name is mostly digits (version dirs, hash suffixes).
        let letters = normalized.filter(\.isLetter)
        guard letters.count >= 3 else { return nil }

        return fallbackName(for: cleaned)
    }

    private static func isBundleIDLike(_ string: String) -> Bool {
        string.contains(".") && !string.contains(" ")
    }

    private static func splitCamelCase(_ string: String) -> String {
        var result = ""
        for (index, char) in string.enumerated() {
            if char.isUppercase, index > 0 {
                let previous = string[string.index(string.startIndex, offsetBy: index - 1)]
                if previous.isLowercase || previous.isNumber {
                    result.append(" ")
                }
            }
            result.append(char)
        }
        return result
    }
}

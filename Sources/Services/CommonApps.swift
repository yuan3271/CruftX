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
    /// "com.tencent.xinWeChat.Helper" still resolves to 微信).
    static func displayName(for bundleID: String) -> String? {
        guard useDatabase else { return nil }
        if let exact = database[bundleID] {
            return exact
        }
        let lower = bundleID.lowercased()
        for (key, name) in database where lower.hasPrefix(key.lowercased() + ".") {
            return name
        }
        return nil
    }
}

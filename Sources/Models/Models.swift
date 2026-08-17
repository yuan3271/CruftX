import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case dailyJunk
    case uninstallResidue
    case officeClean
    case uninstall
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "概览"
        case .dailyJunk: return "日常垃圾"
        case .uninstallResidue: return "卸载残留"
        case .officeClean: return "办公专清"
        case .uninstall: return "卸载应用"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.50percent"
        case .dailyJunk: return "trash"
        case .uninstallResidue: return "square.grid.2x2"
        case .officeClean: return "bubble.left.and.bubble.right"
        case .uninstall: return "xmark.app"
        case .settings: return "gearshape"
        }
    }
}

/// Kinds of daily junk that can be scanned.
enum JunkKind: String, CaseIterable, Identifiable {
    case caches
    case logs
    case diagnosticReports
    case derivedData
    case tempFiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caches: return "应用缓存"
        case .logs: return "日志文件"
        case .diagnosticReports: return "诊断报告"
        case .derivedData: return "Xcode 派生数据"
        case .tempFiles: return "临时文件"
        }
    }

    var icon: String {
        switch self {
        case .caches: return "cylinder.split.1x2"
        case .logs: return "doc.text"
        case .diagnosticReports: return "exclamationmark.triangle"
        case .derivedData: return "hammer"
        case .tempFiles: return "clock"
        }
    }

    var detail: String {
        switch self {
        case .caches: return "应用运行时生成的缓存，可安全重建"
        case .logs: return "应用与系统的日志输出"
        case .diagnosticReports: return "崩溃报告与诊断数据"
        case .derivedData: return "Xcode 构建产物，重新打开项目时会重建"
        case .tempFiles: return "系统临时目录中当前用户的文件"
        }
    }

    /// Kinds checked by default in a scan. Conservative by design:
    /// regenerable, low-value files are checked; large caches are not.
    var isDefaultSafe: Bool {
        switch self {
        case .tempFiles, .logs:
            return true
        case .caches, .diagnosticReports, .derivedData:
            return false
        }
    }
}

/// Kinds of uninstall residue locations.
enum ResidueKind: String, CaseIterable, Identifiable {
    case applicationSupport
    case caches
    case preferences
    case savedState
    case httpStorage
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .applicationSupport: return "应用支持文件"
        case .caches: return "缓存"
        case .preferences: return "偏好设置"
        case .savedState: return "已保存的窗口状态"
        case .httpStorage: return "网络存储"
        case .logs: return "日志"
        }
    }

    var icon: String {
        switch self {
        case .applicationSupport: return "folder"
        case .caches: return "cylinder.split.1x2"
        case .preferences: return "slider.horizontal.3"
        case .savedState: return "macwindow"
        case .httpStorage: return "globe"
        case .logs: return "doc.text"
        }
    }
}

/// Categories inside office/chat app specialized cleaning.
enum OfficeKind: String, CaseIterable, Identifiable {
    case appCache
    case imageCache
    case videoCache
    case fileCache
    case tempCache
    case otherCache

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appCache: return "应用缓存"
        case .imageCache: return "图片缓存"
        case .videoCache: return "视频缓存"
        case .fileCache: return "文件缓存"
        case .tempCache: return "临时文件"
        case .otherCache: return "其他缓存"
        }
    }

    var icon: String {
        switch self {
        case .appCache: return "cylinder.split.1x2"
        case .imageCache: return "photo"
        case .videoCache: return "video"
        case .fileCache: return "doc"
        case .tempCache: return "clock"
        case .otherCache: return "ellipsis.circle"
        }
    }
}

/// A single discovered item, either daily junk or uninstall residue.
struct JunkItem: Identifiable, Sendable {
    let id: String
    let name: String
    let path: URL
    let sizeBytes: Int64
    let kind: JunkKind?
    let residueKind: ResidueKind?
    var officeKind: OfficeKind? = nil
    let appName: String?
    var isSelected: Bool = true

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var isResidue: Bool { appName != nil || residueKind != nil }
}

/// Immutable snapshot produced by a background scanner.
struct ScannedEntry: Sendable, Identifiable {
    let name: String
    let path: URL
    let sizeBytes: Int64
    let kind: JunkKind?
    let residueKind: ResidueKind?
    var officeKind: OfficeKind? = nil
    let appName: String?

    var id: String {
        path.path
    }
}

/// Specialized cleaning result for one office/chat app, with branches.
struct OfficeScanGroup: Identifiable {
    let id: String
    let appName: String
    var bundleID: String? = nil
    var branches: [ScanGroup]

    var totalBytes: Int64 {
        branches.reduce(0) { $0 + $1.totalBytes }
    }

    var itemCount: Int {
        branches.reduce(0) { $0 + $1.items.count }
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}

/// An installed application shown in the uninstall tool.
struct InstalledAppInfo: Identifiable, Sendable {
    let id: String
    let name: String
    let path: URL
    let bundleID: String?
    let sizeBytes: Int64

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

struct ScanGroup: Identifiable {
    let id: String
    let title: String
    let icon: String
    let detail: String?
    var subtitle: String? = nil
    var items: [JunkItem]

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}

struct CleanSummary {
    let freedBytes: Int64
    let itemCount: Int
    let failedPaths: [String]

    var freedText: String {
        ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)
    }
}

extension Int64 {
    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

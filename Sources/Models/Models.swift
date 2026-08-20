import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case dailyJunk
    case uninstallResidue
    case uninstall
    case recycleBin
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return L10n.tr("dashboard", default: "概览")
        case .dailyJunk: return L10n.tr("daily_junk", default: "日常垃圾")
        case .uninstallResidue: return L10n.tr("uninstall_residue", default: "卸载残留")
        case .uninstall: return L10n.tr("uninstall_app", default: "卸载应用")
        case .recycleBin: return L10n.tr("recycle_bin", default: "回收站")
        case .settings: return L10n.tr("settings", default: "设置")
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.50percent"
        case .dailyJunk: return "trash"
        case .uninstallResidue: return "square.grid.2x2"
        case .uninstall: return "xmark.app"
        case .recycleBin: return "arrow.uturn.backward.circle"
        case .settings: return "gearshape"
        }
    }
}

/// How risky it is to delete an item. Low-risk content is checked by default;
/// medium and high require explicit confirmation.
enum CleanupRisk: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return L10n.tr("risk_low", default: "低风险")
        case .medium: return L10n.tr("risk_medium", default: "中风险")
        case .high: return L10n.tr("risk_high", default: "高风险")
        }
    }

    var icon: String {
        switch self {
        case .low: return "checkmark.shield"
        case .medium: return "exclamationmark.shield"
        case .high: return "exclamationmark.octagon"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var detail: String {
        switch self {
        case .low: return L10n.tr("risk_low_detail", default: "可重建或价值低，默认勾选")
        case .medium: return L10n.tr("risk_medium_detail", default: "可能含个人数据，请确认后清理")
        case .high: return L10n.tr("risk_high_detail", default: "可能含不可恢复的数据，谨慎清理")
        }
    }

    static func max(_ a: CleanupRisk, _ b: CleanupRisk) -> CleanupRisk {
        a.rank >= b.rank ? a : b
    }

    private var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
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
        case .caches: return L10n.tr("junk_kind_caches", default: "应用缓存")
        case .logs: return L10n.tr("junk_kind_logs", default: "日志文件")
        case .diagnosticReports: return L10n.tr("junk_kind_diagnostics", default: "诊断报告")
        case .derivedData: return L10n.tr("junk_kind_derived", default: "Xcode 派生数据")
        case .tempFiles: return L10n.tr("junk_kind_temp", default: "临时文件")
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
        case .caches: return L10n.tr("junk_kind_caches_detail", default: "应用运行时生成的缓存，可安全重建")
        case .logs: return L10n.tr("junk_kind_logs_detail", default: "应用与系统的日志输出")
        case .diagnosticReports: return L10n.tr("junk_kind_diagnostics_detail", default: "崩溃报告与诊断数据")
        case .derivedData: return L10n.tr("junk_kind_derived_detail", default: "Xcode 构建产物，重新打开项目时会重建")
        case .tempFiles: return L10n.tr("junk_kind_temp_detail", default: "系统临时目录中当前用户的文件")
        }
    }

    var risk: CleanupRisk {
        switch self {
        case .caches, .logs, .tempFiles:
            return .low
        case .diagnosticReports, .derivedData:
            return .medium
        }
    }
}

/// Kinds of uninstall residue locations.
enum ResidueKind: String, CaseIterable, Identifiable {
    case applicationSupport
    case containers
    case caches
    case preferences
    case savedState
    case httpStorage
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .applicationSupport: return L10n.tr("residue_kind_app_support", default: "应用支持文件")
        case .containers: return L10n.tr("residue_kind_containers", default: "容器数据")
        case .caches: return L10n.tr("residue_kind_caches", default: "缓存")
        case .preferences: return L10n.tr("residue_kind_prefs", default: "偏好设置")
        case .savedState: return L10n.tr("residue_kind_saved_state", default: "已保存的窗口状态")
        case .httpStorage: return L10n.tr("residue_kind_http", default: "网络存储")
        case .logs: return L10n.tr("residue_kind_logs", default: "日志")
        }
    }

    var icon: String {
        switch self {
        case .applicationSupport: return "folder"
        case .containers: return "shippingbox"
        case .caches: return "cylinder.split.1x2"
        case .preferences: return "slider.horizontal.3"
        case .savedState: return "macwindow"
        case .httpStorage: return "globe"
        case .logs: return "doc.text"
        }
    }

    var risk: CleanupRisk {
        switch self {
        case .caches, .logs:
            return .medium
        case .applicationSupport, .containers, .preferences, .savedState, .httpStorage:
            return .high
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
        case .appCache: return L10n.tr("office_kind_app_cache", default: "应用缓存")
        case .imageCache: return L10n.tr("office_kind_image", default: "图片缓存")
        case .videoCache: return L10n.tr("office_kind_video", default: "视频缓存")
        case .fileCache: return L10n.tr("office_kind_file", default: "文件缓存")
        case .tempCache: return L10n.tr("office_kind_temp", default: "临时文件")
        case .otherCache: return L10n.tr("office_kind_other", default: "其他缓存")
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

    var risk: CleanupRisk {
        switch self {
        case .appCache, .tempCache:
            return .low
        case .imageCache, .videoCache, .otherCache:
            return .medium
        case .fileCache:
            return .high
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

    var risk: CleanupRisk {
        if let residueKind { return residueKind.risk }
        if let officeKind { return officeKind.risk }
        if let kind { return kind.risk }
        return .medium
    }

    /// Default selection rule: only low-risk, regenerable content.
    var isDefaultChecked: Bool { risk == .low }
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
struct OfficeScanGroup: Identifiable, Sendable {
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

struct ScanGroup: Identifiable, Sendable {
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

    var maxRisk: CleanupRisk {
        items.reduce(.low) { CleanupRisk.max($0, $1.risk) }
    }

    var lowRiskCount: Int { items.filter { $0.risk == .low }.count }
    var mediumRiskCount: Int { items.filter { $0.risk == .medium }.count }
    var highRiskCount: Int { items.filter { $0.risk == .high }.count }
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

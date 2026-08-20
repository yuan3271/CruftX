import AppKit
import SwiftUI

enum CheckState {
    case checked
    case partial
    case unchecked
}

struct CheckboxButton: View {
    let state: CheckState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            switch state {
            case .checked:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            case .partial:
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.orange)
            case .unchecked:
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 18))
        .help(state == .partial
              ? L10n.tr("partial_help", default: "部分选中，点击全选")
              : L10n.tr("toggle_help", default: "点击切换本分支全部项目"))
    }
}

/// A disclosure branch header with an all/none toggle, like 火绒-style
/// cleaning trees: a checkbox that reflects checked/partial/unchecked state.
struct BranchHeader: View {
    let icon: String
    let title: String
    let detail: String?
    let tint: Color
    let selectedCount: Int
    let totalCount: Int
    let sizeText: String
    var risk: CleanupRisk? = nil
    let onToggleAll: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CheckboxButton(state: state, action: onToggleAll)

            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let risk {
                RiskBadge(risk: risk)
            }

            Text("\(selectedCount)/\(totalCount) 项 · \(sizeText)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var state: CheckState {
        if selectedCount == 0 { return .unchecked }
        return selectedCount == totalCount ? .checked : .partial
    }
}

/// Rows inside a branch: item checkbox + name + size + "show in Finder".
struct BranchItemRow: View {
    let item: JunkItem
    let onToggle: () -> Void
    var onIgnoreTemporary: (() -> Void)? = nil
    var onIgnorePermanent: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            CheckboxButton(state: item.isSelected ? .checked : .unchecked, action: onToggle)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(1)
                    RiskBadge(risk: item.risk, compact: true)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.sizeText)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.path])
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L10n.tr("show_in_finder", default: "在 Finder 中显示"))
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.path])
            } label: {
                Label(L10n.tr("show_in_finder", default: "在 Finder 中显示"), systemImage: "magnifyingglass")
            }
            if let onIgnoreTemporary {
                Button {
                    onIgnoreTemporary()
                } label: {
                    Label(L10n.tr("ignore_7d", default: "暂时忽略 7 天"), systemImage: "clock.badge.questionmark")
                }
            }
            if let onIgnorePermanent {
                Button {
                    onIgnorePermanent()
                } label: {
                    Label(L10n.tr("ignore_forever", default: "永久忽略"), systemImage: "eye.slash")
                }
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let appName = item.appName {
            parts.append(appName)
        }
        if let officeKind = item.officeKind {
            parts.append(officeKind.title)
        }
        if let residueKind = item.residueKind {
            parts.append(residueKind.title)
        }
        if let kind = item.kind {
            parts.append(kind.title)
        }
        return parts.joined(separator: " · ")
    }
}

/// Small colored capsule showing a cleanup risk level.
struct RiskBadge: View {
    let risk: CleanupRisk
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: risk.icon)
                .font(.system(size: compact ? 8 : 9, weight: .semibold))
            Text(risk.title)
                .font(.system(size: compact ? 9 : 10, weight: .semibold))
        }
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 2 : 3)
        .foregroundStyle(risk.color)
        .background(risk.color.opacity(0.12), in: Capsule())
        .help(risk.detail)
    }
}

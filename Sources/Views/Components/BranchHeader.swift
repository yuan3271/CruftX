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
        .help(state == .partial ? "部分选中，点击全选" : "点击切换本分支全部项目")
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

    var body: some View {
        HStack(spacing: 12) {
            CheckboxButton(state: item.isSelected ? .checked : .unchecked, action: onToggle)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
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
            .help("在 Finder 中显示")
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.path])
            } label: {
                Label("在 Finder 中显示", systemImage: "magnifyingglass")
            }
        }
    }

    private var subtitle: String {
        if let officeKind = item.officeKind {
            return officeKind.title
        }
        if let residueKind = item.residueKind {
            return residueKind.title
        }
        if let kind = item.kind {
            return kind.title
        }
        return ""
    }
}

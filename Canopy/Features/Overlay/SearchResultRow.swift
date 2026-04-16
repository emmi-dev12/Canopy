import SwiftUI
import AppKit

/// A single row in the search results list, covering apps, actions, and folders.
struct SearchResultRow: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.displayTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !result.displaySubtitle.isEmpty {
                    Text(result.displaySubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Folder member count badge
            if case .folder(let folder) = result, !folder.memberBundleIDs.isEmpty {
                Text("\(folder.memberBundleIDs.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .tertiaryLabelColor).opacity(0.3))
                    )
            }

            // Chevron for folders (indicates drill-in)
            if case .folder = result {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())  // makes entire row hittable
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconView: some View {
        if let nsImage = result.displayIcon {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else if let symbol = result.sfSymbolName {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(symbolColor)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }

    private var symbolColor: Color {
        switch result {
        case .action: return .secondary
        case .folder: return .blue
        case .app:    return .secondary
        }
    }

    private var rowHeight: CGFloat {
        switch result {
        case .app, .folder: return 44
        case .action:       return 36
        }
    }
}

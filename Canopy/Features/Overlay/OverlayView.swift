import SwiftUI
import AppKit

/// The root SwiftUI view for the floating search overlay.
/// Uses NSVisualEffectView for frosted glass and NSHostingView for embedding.
struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            // Frosted glass background
            VisualEffectBackground()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 0) {
                searchField
                Divider().opacity(0.4)
                resultsPanel
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(width: 620, height: 480)
        .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 10)
        .onAppear { isSearchFocused = true }
        .onKeyPress(.escape) {
            viewModel.handleEscape()
            return .handled
        }
        .onKeyPress(.upArrow) {
            viewModel.selectPrevious()
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.selectNext()
            return .handled
        }
        .onKeyPress(.return) {
            viewModel.activateSelected()
            return .handled
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            // Back button when inside a folder
            if let folder = viewModel.activeFolderFilter {
                Button(action: viewModel.exitFolderDrill) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)

                Image(systemName: folder.sfSymbol)
                    .foregroundStyle(.blue)
                    .font(.system(size: 17, weight: .medium))
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 17, weight: .medium))
                    .padding(.leading, 16)
            }

            TextField(
                viewModel.activeFolderFilter != nil
                    ? "Search in \(viewModel.activeFolderFilter!.name)…"
                    : "Search menubar apps…",
                text: $viewModel.query
            )
            .textFieldStyle(.plain)
            .font(.system(size: 18, weight: .regular))
            .focused($isSearchFocused)
            .padding(.vertical, 14)

            if !viewModel.query.isEmpty {
                Button(action: { viewModel.query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }
        }
        .padding(.trailing, viewModel.query.isEmpty ? 16 : 0)
    }

    // MARK: - Results panel

    private var resultsPanel: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    let appResults = viewModel.results.filter {
                        if case .app = $0 { return true }; return false
                    }
                    let actionResults = viewModel.results.filter {
                        if case .action = $0 { return true }; return false
                    }
                    let folderResults = viewModel.results.filter {
                        if case .folder = $0 { return true }; return false
                    }
                    let revealResults = viewModel.results.filter {
                        if case .reveal = $0 { return true }; return false
                    }

                    if !appResults.isEmpty {
                        Section(header: sectionHeader("Apps")) {
                            ForEach(Array(appResults.enumerated()), id: \.element.id) { (offset, result) in
                                let globalIdx = viewModel.results.firstIndex(of: result) ?? 0
                                SearchResultRow(
                                    result: result,
                                    isSelected: globalIdx == viewModel.selectedIndex
                                )
                                .id(result.id)
                                .onTapGesture { viewModel.activate(result) }
                                .onHover { if $0 { viewModel.select(at: globalIdx) } }
                            }
                        }
                    }

                    if !actionResults.isEmpty {
                        Section(header: sectionHeader("Actions")) {
                            ForEach(Array(actionResults.enumerated()), id: \.element.id) { (_, result) in
                                let globalIdx = viewModel.results.firstIndex(of: result) ?? 0
                                SearchResultRow(
                                    result: result,
                                    isSelected: globalIdx == viewModel.selectedIndex
                                )
                                .id(result.id)
                                .onTapGesture { viewModel.activate(result) }
                                .onHover { if $0 { viewModel.select(at: globalIdx) } }
                            }
                        }
                    }

                    if !folderResults.isEmpty {
                        Section(header: sectionHeader("Folders")) {
                            ForEach(Array(folderResults.enumerated()), id: \.element.id) { (_, result) in
                                let globalIdx = viewModel.results.firstIndex(of: result) ?? 0
                                SearchResultRow(
                                    result: result,
                                    isSelected: globalIdx == viewModel.selectedIndex
                                )
                                .id(result.id)
                                .onTapGesture { viewModel.activate(result) }
                                .onHover { if $0 { viewModel.select(at: globalIdx) } }
                            }
                        }
                    }

                    // "Open in menu bar →" fallback rows — always last, visually de-emphasized
                    if !revealResults.isEmpty {
                        Section(header: sectionHeader("Open in Menu Bar")) {
                            ForEach(Array(revealResults.enumerated()), id: \.element.id) { (_, result) in
                                let globalIdx = viewModel.results.firstIndex(of: result) ?? 0
                                SearchResultRow(
                                    result: result,
                                    isSelected: globalIdx == viewModel.selectedIndex
                                )
                                .id(result.id)
                                .onTapGesture { viewModel.activate(result) }
                                .onHover { if $0 { viewModel.select(at: globalIdx) } }
                            }
                        }
                    }

                    if viewModel.results.isEmpty {
                        emptyState
                    }
                }
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.selectedIndex) { _, idx in
                guard idx < viewModel.results.count else { return }
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(viewModel.results[idx].id, anchor: .center)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .background(.clear)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(viewModel.query.isEmpty ? "Start typing to search" : "No results for "\(viewModel.query)"")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - NSVisualEffectView wrapper

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

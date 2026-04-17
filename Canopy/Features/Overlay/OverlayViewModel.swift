import Foundation
import Combine
import AppKit

/// Drives the Overlay UI. Runs search queries and records selections.
@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var selectedIndex: Int = 0
    @Published private(set) var isLoading: Bool = false

    /// Set when the user drills into a folder.
    @Published private(set) var activeFolderFilter: AppFolder? = nil

    private let searchEngine: SearchEngine
    private let rankingService: RankingService
    private let activator: MenuItemActivator
    private var cancellables = Set<AnyCancellable>()

    var onDismiss: (() -> Void)?

    init(searchEngine: SearchEngine, rankingService: RankingService) {
        self.searchEngine = searchEngine
        self.rankingService = rankingService
        self.activator = MenuItemActivator()

        // Debounce query to avoid re-searching on every keystroke
        $query
            .debounce(for: .milliseconds(60), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] q in
                self?.runSearch(query: q)
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func prepareForPresentation() {
        query = ""
        activeFolderFilter = nil
        selectedIndex = 0
        runSearch(query: "")
    }

    func clearOnDismiss() {
        query = ""
        activeFolderFilter = nil
    }

    // MARK: - Search

    private func runSearch(query: String) {
        var raw = searchEngine.search(query: query)

        // If inside a folder, filter to that folder's members only
        if let folder = activeFolderFilter {
            raw = raw.filter { result in
                switch result {
                case .app(let app):
                    return folder.memberBundleIDs.contains(app.bundleIdentifier)
                case .action(_, let owner):
                    return folder.memberBundleIDs.contains(owner.bundleIdentifier)
                case .folder:
                    return false
                case .reveal(let app):
                    return folder.memberBundleIDs.contains(app.bundleIdentifier)
                }
            }
        }

        results = raw
        // Clamp selectedIndex
        if selectedIndex >= results.count {
            selectedIndex = results.isEmpty ? 0 : results.count - 1
        }
    }

    // MARK: - Navigation

    func selectNext() {
        guard !results.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, results.count - 1)
    }

    func selectPrevious() {
        guard !results.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }

    func select(at index: Int) {
        selectedIndex = index
    }

    // MARK: - Activation

    /// Executes the currently selected result.
    func activateSelected() {
        guard selectedIndex < results.count else { return }
        activate(results[selectedIndex])
    }

    func activate(_ result: SearchResult) {
        switch result {
        case .app(let app):
            rankingService.recordUse(key: app.bundleIdentifier, query: query)
            launchApp(app)
            onDismiss?()

        case .action(let action, let ownerApp):
            rankingService.recordUse(key: action.id, query: query)
            onDismiss?()
            Task {
                try? await activator.activate(action, in: ownerApp)
            }

        case .folder(let folder):
            rankingService.recordUse(key: "folder::\(folder.id.uuidString)", query: query)
            activeFolderFilter = folder
            query = ""

        case .reveal(let app):
            // Graceful fallback: bring the app's menubar item to focus so the user can
            // interact with it directly. Still useful even when AX didn't find actions.
            rankingService.recordUse(key: "reveal::\(app.bundleIdentifier)", query: query)
            launchApp(app)
            onDismiss?()
        }
    }

    func exitFolderDrill() {
        activeFolderFilter = nil
        query = ""
    }

    // MARK: - Keyboard handling

    func handleEscape() {
        if activeFolderFilter != nil {
            exitFolderDrill()
        } else {
            onDismiss?()
        }
    }

    // MARK: - Private helpers

    private func launchApp(_ app: MenubarApp) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
        if let ra = running.first {
            ra.activate(options: [.activateIgnoringOtherApps])
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }
}

import AppKit
import Combine

/// Single dependency container for Canopy.
/// Wires all services together at launch and is passed as `.environmentObject` to SwiftUI views.
///
/// Uses protocol injection for SearchEngine and RankingService so they remain unit-testable
/// without the full environment graph.
@MainActor
final class AppEnvironment: ObservableObject {

    // MARK: - Services (injected via protocols in tests, concrete here in production)

    let persistence: PersistenceController
    let usageStore: UsageStore
    let folderStore: FolderStore
    let rankingService: RankingService
    let accessibility: AccessibilityService
    let discovery: AppDiscoveryService
    let searchEngine: SearchEngine
    let hotkeyService: HotkeyService
    let overlayViewModel: OverlayViewModel
    let overlayController: OverlayWindowController
    let statusItemController: StatusItemController

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        persistence = PersistenceController.shared
        usageStore = UsageStore(persistence: persistence)
        folderStore = FolderStore(persistence: persistence)
        rankingService = RankingService(usageStore: usageStore)
        accessibility = AccessibilityService()
        discovery = AppDiscoveryService()
        searchEngine = SearchEngine(ranking: rankingService)
        hotkeyService = HotkeyService()
        statusItemController = StatusItemController()

        // OverlayViewModel needs searchEngine and rankingService — build it first,
        // then pass it into OverlayWindowController.
        overlayViewModel = OverlayViewModel(searchEngine: searchEngine, rankingService: rankingService)
        overlayController = OverlayWindowController(viewModel: overlayViewModel)

        // Dismiss callback
        overlayViewModel.onDismiss = { [weak self] in
            Task { @MainActor in self?.overlayController.hide() }
        }
    }

    // MARK: - Start (called from AppDelegate.applicationDidFinishLaunching)

    func start() {
        // Hotkey → overlay
        hotkeyService.onActivate = { [weak self] in
            Task { @MainActor in self?.overlayController.toggle() }
        }

        // Input Monitoring unavailable banner
        NotificationCenter.default.addObserver(
            forName: .canopyInputMonitoringUnavailable,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Post-MVP: show banner in StatusMenuView
            _ = self
        }

        // Discovery → search engine index
        discovery.$menubarApps
            .receive(on: RunLoop.main)
            .sink { [weak self] apps in
                self?.searchEngine.updateAppIndex(apps)
            }
            .store(in: &cancellables)

        // Folder changes → search engine index
        folderStore.$folders
            .receive(on: RunLoop.main)
            .sink { [weak self] folders in
                self?.searchEngine.updateFolderIndex(folders)
            }
            .store(in: &cancellables)

        // AX permission gained mid-session → re-enumerate all discovered apps
        accessibility.$isTrusted
            .removeDuplicates()
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                for app in self.discovery.menubarApps {
                    self.searchEngine.reenumerate(app: app)
                }
            }
            .store(in: &cancellables)

        // Status item
        statusItemController.setup()
        statusItemController.onToggleOverlay = { [weak self] in
            Task { @MainActor in self?.overlayController.toggle() }
        }
        statusItemController.onOpenSettings = {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }

        // Start discovering apps
        discovery.startMonitoring()

        // Load saved hotkey (default: ⌥Space)
        if let prefs = persistence.load(HotkeyPrefs.self, from: persistence.hotkeyPrefsURL) {
            hotkeyService.register(
                keyCode: prefs.keyCode,
                modifiers: NSEvent.ModifierFlags(rawValue: UInt(prefs.modifierFlags))
            )
        } else {
            hotkeyService.register(keyCode: 49, modifiers: [.option])  // ⌥Space
        }

        // Show permissions onboarding if needed (first launch or AX not granted)
        if !accessibility.isTrusted {
            showPermissionsIfNeeded()
        }
    }

    // MARK: - Private

    private func showPermissionsIfNeeded() {
        // Only show on first launch (tracked via UserDefaults)
        let key = "canopy.onboardingComplete"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        // Open the settings window to the Permissions tab
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}

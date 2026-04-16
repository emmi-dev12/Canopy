import AppKit
import Combine

/// Discovers and monitors running applications that have menubar presence.
/// Publishes an updated list whenever apps launch or quit.
final class AppDiscoveryService: ObservableObject {
    @Published private(set) var menubarApps: [MenubarApp] = []

    private let monitor: RunningAppsMonitor
    private let checker: MenubarPresenceChecker
    private var cancellables = Set<AnyCancellable>()

    init(monitor: RunningAppsMonitor = RunningAppsMonitor(),
         checker: MenubarPresenceChecker = MenubarPresenceChecker()) {
        self.monitor = monitor
        self.checker = checker
    }

    /// Begin monitoring. Performs an immediate scan then listens for launch/quit events.
    func startMonitoring() {
        refresh()

        // Debounce app launch/quit bursts (e.g. during login)
        monitor.appLaunched
            .merge(with: monitor.appTerminated)
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    /// Force a fresh scan of all running applications.
    func refresh() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { checker.likelyHasMenubarPresence($0) }
            .map { MenubarApp(from: $0) }
        // Preserve existing folder assignments and usage scores
        let existing = Dictionary(uniqueKeysWithValues: menubarApps.map { ($0.bundleIdentifier, $0) })
        menubarApps = apps.map { app in
            var updated = app
            if let prev = existing[app.bundleIdentifier] {
                updated.folderID = prev.folderID
                updated.usageScore = prev.usageScore
            }
            return updated
        }
    }

    /// Updates the folderID and usageScore for an app identified by bundle identifier.
    func updateApp(_ bundleID: String, folderID: UUID?, usageScore: Double? = nil) {
        guard let idx = menubarApps.firstIndex(where: { $0.bundleIdentifier == bundleID }) else { return }
        menubarApps[idx].folderID = folderID
        if let score = usageScore {
            menubarApps[idx].usageScore = score
        }
    }
}

import AppKit
import Combine

/// Bridges NSWorkspace app-launch/quit notifications into Combine publishers.
final class RunningAppsMonitor {
    /// Fires with the newly launched application.
    let appLaunched: AnyPublisher<NSRunningApplication, Never>
    /// Fires with the application that just quit.
    let appTerminated: AnyPublisher<NSRunningApplication, Never>

    private let launchSubject = PassthroughSubject<NSRunningApplication, Never>()
    private let terminateSubject = PassthroughSubject<NSRunningApplication, Never>()
    private var observers: [NSObjectProtocol] = []

    init() {
        appLaunched = launchSubject.eraseToAnyPublisher()
        appTerminated = terminateSubject.eraseToAnyPublisher()
        subscribe()
    }

    deinit {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    private func subscribe() {
        let center = NSWorkspace.shared.notificationCenter

        let launchObs = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.launchSubject.send(app)
            }
        }

        let terminateObs = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.terminateSubject.send(app)
            }
        }

        observers = [launchObs, terminateObs]
    }
}

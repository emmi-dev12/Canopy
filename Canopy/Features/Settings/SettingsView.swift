import SwiftUI

/// Main preferences window with tabs for General, Folders, and Permissions.
struct SettingsView: View {
    @EnvironmentObject var environment: AppEnvironment

    @State private var hotkeyCode: UInt16 = 49
    @State private var hotkeyModifiers: NSEvent.ModifierFlags = [.option]

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            FolderManagerView(
                folderStore: environment.folderStore,
                allApps: environment.discovery.menubarApps
            )
            .tabItem { Label("Folders", systemImage: "folder") }

            PermissionsView(accessibility: environment.accessibility)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(minWidth: 500, minHeight: 360)
        .onAppear {
            // Load saved hotkey
            if let prefs = environment.persistence.load(HotkeyPrefs.self, from: environment.persistence.hotkeyPrefsURL) {
                hotkeyCode = prefs.keyCode
                hotkeyModifiers = NSEvent.ModifierFlags(rawValue: UInt(prefs.modifierFlags))
            }
        }
    }

    // MARK: - General tab

    private var generalTab: some View {
        Form {
            Section {
                HotkeyRecorderView(
                    keyCode: $hotkeyCode,
                    modifiers: $hotkeyModifiers
                ) { code, mods in
                    environment.hotkeyService.register(keyCode: code, modifiers: mods)
                    let prefs = HotkeyPrefs(keyCode: code, modifierFlags: UInt32(mods.rawValue))
                    environment.persistence.save(prefs, to: environment.persistence.hotkeyPrefsURL)
                }
            } header: {
                Text("Global Hotkey")
            } footer: {
                Text("Press this key combination anywhere to open Canopy.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// Codable hotkey preferences for persistence.
struct HotkeyPrefs: Codable {
    var keyCode: UInt16
    var modifierFlags: UInt32
}

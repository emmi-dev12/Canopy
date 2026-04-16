import Foundation

/// Manages the app's data directory and provides URLs for each JSON store file.
/// Uses JSON files in Application Support rather than Core Data to avoid Xcode-specific
/// tooling requirements and to keep the persistence layer portable.
final class PersistenceController {
    static let shared = PersistenceController()

    let appSupportURL: URL

    private init() {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        appSupportURL = base.appendingPathComponent("Canopy", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: appSupportURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - File URLs

    var usageRecordsURL: URL {
        appSupportURL.appendingPathComponent("usage_records.json")
    }

    var queryContextURL: URL {
        appSupportURL.appendingPathComponent("query_context.json")
    }

    var foldersURL: URL {
        appSupportURL.appendingPathComponent("folders.json")
    }

    var hotkeyPrefsURL: URL {
        appSupportURL.appendingPathComponent("hotkey_prefs.json")
    }

    // MARK: - Generic read/write helpers

    func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

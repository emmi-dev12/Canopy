import Foundation
import Combine

/// Persists and manages AppFolder definitions.
/// Publishes folder changes so the SearchEngine and FolderManagerView stay in sync.
final class FolderStore: ObservableObject {
    @Published private(set) var folders: [AppFolder] = []

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        load()
    }

    // MARK: - CRUD

    func createFolder(name: String, sfSymbol: String = "folder") -> AppFolder {
        let folder = AppFolder(
            name: name,
            sfSymbol: sfSymbol,
            sortOrder: folders.count
        )
        folders.append(folder)
        save()
        return folder
    }

    func renameFolder(_ id: UUID, to name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = name
        save()
    }

    func updateIcon(_ id: UUID, sfSymbol: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].sfSymbol = sfSymbol
        save()
    }

    func deleteFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        // Re-sort
        for i in folders.indices { folders[i].sortOrder = i }
        save()
    }

    /// Adds `bundleID` to folder `id`. No-op if already a member.
    func addApp(_ bundleID: String, to folderID: UUID) {
        guard let idx = folders.firstIndex(where: { $0.id == folderID }) else { return }
        guard !folders[idx].memberBundleIDs.contains(bundleID) else { return }
        folders[idx].memberBundleIDs.append(bundleID)
        save()
    }

    /// Removes `bundleID` from folder `id`.
    func removeApp(_ bundleID: String, from folderID: UUID) {
        guard let idx = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[idx].memberBundleIDs.removeAll { $0 == bundleID }
        save()
    }

    /// Moves `bundleID` from its current folder (if any) to `destinationID`.
    func moveApp(_ bundleID: String, to destinationID: UUID) {
        for idx in folders.indices {
            folders[idx].memberBundleIDs.removeAll { $0 == bundleID }
        }
        addApp(bundleID, to: destinationID)
    }

    func reorderFolders(_ newOrder: [AppFolder]) {
        folders = newOrder.enumerated().map { (i, f) in
            var updated = f
            updated.sortOrder = i
            return updated
        }
        save()
    }

    /// Returns the folder containing a given bundle identifier, if any.
    func folder(containing bundleID: String) -> AppFolder? {
        folders.first { $0.memberBundleIDs.contains(bundleID) }
    }

    // MARK: - Persistence

    private func load() {
        folders = persistence.load([AppFolder].self, from: persistence.foldersURL) ?? []
        folders.sort { $0.sortOrder < $1.sortOrder }
    }

    private func save() {
        persistence.save(folders, to: persistence.foldersURL)
    }
}

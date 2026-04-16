import SwiftUI
import AppKit

/// Displays and manages the user's app folders.
/// Supports creating, renaming, deleting folders, and assigning apps to them.
struct FolderManagerView: View {
    @ObservedObject var folderStore: FolderStore
    let allApps: [MenubarApp]

    @State private var selectedFolderID: UUID? = nil
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var editingFolderID: UUID? = nil
    @State private var editingName = ""

    var body: some View {
        HStack(spacing: 0) {
            folderList
            Divider()
            folderDetail
        }
        .frame(minWidth: 560, minHeight: 340)
    }

    // MARK: - Folder list (left column)

    private var folderList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedFolderID) {
                ForEach(folderStore.folders) { folder in
                    Label(folder.name, systemImage: folder.sfSymbol)
                        .tag(folder.id)
                        .contextMenu {
                            Button("Rename") {
                                editingFolderID = folder.id
                                editingName = folder.name
                            }
                            Divider()
                            Button("Delete Folder", role: .destructive) {
                                folderStore.deleteFolder(folder.id)
                                if selectedFolderID == folder.id { selectedFolderID = nil }
                            }
                        }
                }
                .onMove { from, to in
                    var reordered = folderStore.folders
                    reordered.move(fromOffsets: from, toOffset: to)
                    folderStore.reorderFolders(reordered)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160, maxWidth: 180)

            Divider()

            // Add folder button
            if isCreatingFolder {
                HStack {
                    TextField("Folder name", text: $newFolderName)
                        .textFieldStyle(.plain)
                        .onSubmit { commitCreate() }
                    Button("Add") { commitCreate() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(8)
            } else {
                Button(action: { isCreatingFolder = true; newFolderName = "" }) {
                    Label("New Folder", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
    }

    // MARK: - Folder detail (right column)

    @ViewBuilder
    private var folderDetail: some View {
        if let folderID = selectedFolderID,
           let folder = folderStore.folders.first(where: { $0.id == folderID }) {
            FolderDetailView(
                folder: folder,
                allApps: allApps,
                folderStore: folderStore
            )
        } else {
            VStack {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("Select or create a folder")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions

    private func commitCreate() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let folder = folderStore.createFolder(name: trimmed)
            selectedFolderID = folder.id
        }
        isCreatingFolder = false
        newFolderName = ""
    }
}

// MARK: - Folder detail view

private struct FolderDetailView: View {
    let folder: AppFolder
    let allApps: [MenubarApp]
    let folderStore: FolderStore

    private var memberApps: [MenubarApp] {
        allApps.filter { folder.memberBundleIDs.contains($0.bundleIdentifier) }
    }
    private var nonMemberApps: [MenubarApp] {
        allApps.filter { !folder.memberBundleIDs.contains($0.bundleIdentifier) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(folder.name)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            List {
                Section("In this folder") {
                    if memberApps.isEmpty {
                        Text("No apps yet — add from the list below")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 12))
                    } else {
                        ForEach(memberApps) { app in
                            AppRow(app: app) {
                                folderStore.removeApp(app.bundleIdentifier, from: folder.id)
                            } addAction: nil
                        }
                    }
                }

                if !nonMemberApps.isEmpty {
                    Section("Add apps") {
                        ForEach(nonMemberApps) { app in
                            AppRow(app: app, removeAction: nil) {
                                folderStore.addApp(app.bundleIdentifier, to: folder.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

// MARK: - App row for folder management

private struct AppRow: View {
    let app: MenubarApp
    var removeAction: (() -> Void)?
    var addAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon.rowIcon)
                    .interpolation(.high)
            } else {
                Image(systemName: "app.dashed")
                    .frame(width: 20, height: 20)
            }

            Text(app.name)
                .font(.system(size: 13))

            Spacer()

            if let remove = removeAction {
                Button(action: remove) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else if let add = addAction {
                Button(action: add) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

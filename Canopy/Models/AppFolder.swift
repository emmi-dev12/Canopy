import Foundation

/// A named group of menubar apps. Folders are a Canopy-native concept — they act as
/// smart launchers, not actual menubar icon reorganization.
struct AppFolder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    /// SF Symbol name used as the folder icon in the overlay.
    var sfSymbol: String
    /// Ordered list of bundle identifiers belonging to this folder.
    var memberBundleIDs: [String]
    var sortOrder: Int
    /// Usage score populated by RankingService at query time.
    var usageScore: Double

    init(
        id: UUID = UUID(),
        name: String,
        sfSymbol: String = "folder",
        memberBundleIDs: [String] = [],
        sortOrder: Int = 0,
        usageScore: Double = 0
    ) {
        self.id = id
        self.name = name
        self.sfSymbol = sfSymbol
        self.memberBundleIDs = memberBundleIDs
        self.sortOrder = sortOrder
        self.usageScore = usageScore
    }

    static func == (lhs: AppFolder, rhs: AppFolder) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

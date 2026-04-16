import AppKit
import ApplicationServices

/// Enumerates AX menu items for a menubar app and returns normalized, searchable actions.
/// Enumeration is always performed off the main thread — call sites should use `Task.detached`.
final class MenuItemEnumerator {
    private let normalizer = MenuItemNormalizer()
    private let maxDepth = 4
    private let maxChildrenPerNode = 30  // guard against pathological menus

    /// Enumerate all accessible menu actions for `app`.
    /// Returns an empty array (never throws) if AX is not permitted or the app has no AX tree.
    func enumerate(for app: MenubarApp) async -> [NormalizedMenuAction] {
        guard AXIsProcessTrusted() else { return [] }
        let axApp = AXHelpers.applicationElement(for: app.pid)
        guard let menuBar: AXUIElement = AXHelpers.menuBar(of: axApp) else { return [] }

        var results: [NormalizedMenuAction] = []
        let children = AXHelpers.children(of: menuBar) ?? []

        for child in children.prefix(20) {  // top-level status items
            let items = enumerateNode(
                child,
                ownerBundleID: app.bundleIdentifier,
                path: [],
                depth: 0
            )
            results.append(contentsOf: items)
        }

        return deduplicated(results)
    }

    // MARK: - Recursive traversal

    private func enumerateNode(
        _ element: AXUIElement,
        ownerBundleID: String,
        path: [String],
        depth: Int
    ) -> [NormalizedMenuAction] {
        guard depth < maxDepth else { return [] }

        let rawTitle = AXHelpers.title(of: element) ?? ""
        let role = AXHelpers.role(of: element) ?? ""
        let cleanedTitle = normalizer.clean(rawTitle)
        let currentPath = cleanedTitle.isEmpty ? path : path + [cleanedTitle]

        var results: [NormalizedMenuAction] = []

        // If this is a menu item (not a container), emit it
        if role == "AXMenuItem" || role == "AXStaticText" {
            if let action = normalizer.normalize(
                rawTitle: rawTitle,
                flatPath: currentPath,
                ownerBundleID: ownerBundleID
            ) {
                results.append(action)
            }
        }

        // Recurse into children
        let children = (AXHelpers.children(of: element) ?? []).prefix(maxChildrenPerNode)
        for child in children {
            let childItems = enumerateNode(
                child,
                ownerBundleID: ownerBundleID,
                path: currentPath,
                depth: depth + 1
            )
            results.append(contentsOf: childItems)
        }

        return results
    }

    // MARK: - De-duplication

    private func deduplicated(_ actions: [NormalizedMenuAction]) -> [NormalizedMenuAction] {
        var seen = Set<String>()
        return actions.filter { action in
            guard !seen.contains(action.id) else { return false }
            seen.insert(action.id)
            return true
        }
    }
}

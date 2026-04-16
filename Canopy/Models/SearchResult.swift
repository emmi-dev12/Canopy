import AppKit

/// A unified result type returned by SearchEngine, covering apps, actions, and folders.
enum SearchResult: Identifiable {
    case app(MenubarApp)
    case action(NormalizedMenuAction, ownerApp: MenubarApp)
    case folder(AppFolder)
    /// Fallback shown when an app matches the query but no specific action could be found.
    /// Activates the app so the user can interact with its menubar item manually.
    case reveal(MenubarApp)

    var id: String {
        switch self {
        case .app(let a):        return "app::\(a.bundleIdentifier)"
        case .action(let a, _): return "action::\(a.id)"
        case .folder(let f):    return "folder::\(f.id.uuidString)"
        case .reveal(let a):    return "reveal::\(a.bundleIdentifier)"
        }
    }

    var score: Double {
        switch self {
        case .app(let a):        return a.usageScore
        case .action(let a, _): return a.usageScore
        case .folder(let f):    return f.usageScore
        case .reveal(let a):    return a.usageScore * 0.5  // ranked below real results
        }
    }

    var displayTitle: String {
        switch self {
        case .app(let a):        return a.name
        case .action(let a, _): return a.displayTitle
        case .folder(let f):    return f.name
        case .reveal(let a):    return "Open \(a.name) in menu bar"
        }
    }

    var displaySubtitle: String {
        switch self {
        case .app:                    return ""
        case .action(let a, let app): return "\(app.name) › \(a.flatPath.dropLast().joined(separator: " › "))"
        case .folder(let f):          return "\(f.memberBundleIDs.count) apps"
        case .reveal:                 return "Reveal app · no actions available"
        }
    }

    var displayIcon: NSImage? {
        switch self {
        case .app(let a):         return a.icon
        case .action(_, let app): return app.icon
        case .folder:             return nil
        case .reveal(let a):      return a.icon
        }
    }

    var sfSymbolName: String? {
        switch self {
        case .app:               return nil
        case .action:            return "gearshape"
        case .folder(let f):     return f.sfSymbol
        case .reveal:            return "arrow.up.forward.app"
        }
    }
}

extension SearchResult: Equatable {
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

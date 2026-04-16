import AppKit

/// A unified result type returned by SearchEngine, covering apps, actions, and folders.
enum SearchResult: Identifiable {
    case app(MenubarApp)
    case action(NormalizedMenuAction, ownerApp: MenubarApp)
    case folder(AppFolder)

    var id: String {
        switch self {
        case .app(let a):        return "app::\(a.bundleIdentifier)"
        case .action(let a, _): return "action::\(a.id)"
        case .folder(let f):    return "folder::\(f.id.uuidString)"
        }
    }

    var score: Double {
        switch self {
        case .app(let a):        return a.usageScore
        case .action(let a, _): return a.usageScore
        case .folder(let f):    return f.usageScore
        }
    }

    var displayTitle: String {
        switch self {
        case .app(let a):        return a.name
        case .action(let a, _): return a.displayTitle
        case .folder(let f):    return f.name
        }
    }

    var displaySubtitle: String {
        switch self {
        case .app:               return ""
        case .action(let a, let app): return "\(app.name) › \(a.flatPath.dropLast().joined(separator: " › "))"
        case .folder(let f):    return "\(f.memberBundleIDs.count) apps"
        }
    }

    var displayIcon: NSImage? {
        switch self {
        case .app(let a):        return a.icon
        case .action(_, let app): return app.icon
        case .folder:            return nil   // rendered as SF Symbol in the UI
        }
    }

    var sfSymbolName: String? {
        switch self {
        case .app:    return nil
        case .action: return "gearshape"
        case .folder(let f): return f.sfSymbol
        }
    }
}

extension SearchResult: Equatable {
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

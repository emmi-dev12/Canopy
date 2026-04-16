import AppKit
import ApplicationServices

/// Type-safe wrappers around AXUIElement attribute access.
/// All functions return nil rather than throwing to simplify call sites — AX errors
/// are expected and common (apps with no AX support, elements that disappeared, etc.).
enum AXHelpers {

    // MARK: - Generic attribute fetch

    /// Reads an AX attribute and casts it to `T`. Returns nil on any error.
    static func attribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success, let v = value else { return nil }
        return v as? T
    }

    // MARK: - Typed convenience accessors

    static func title(of element: AXUIElement) -> String? {
        attribute(element, kAXTitleAttribute)
    }

    static func role(of element: AXUIElement) -> String? {
        attribute(element, kAXRoleAttribute)
    }

    static func children(of element: AXUIElement) -> [AXUIElement]? {
        attribute(element, kAXChildrenAttribute) as [AXUIElement]?
    }

    static func menuBar(of app: AXUIElement) -> AXUIElement? {
        attribute(app, kAXMenuBarAttribute)
    }

    static func isEnabled(_ element: AXUIElement) -> Bool {
        (attribute(element, kAXEnabledAttribute) as Bool?) ?? true
    }

    static func value(of element: AXUIElement) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    // MARK: - Action helpers

    /// Returns the list of available AX action names for an element.
    static func actionNames(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success,
              let arr = names as? [String] else { return [] }
        return arr
    }

    /// Performs an AX action on an element. Returns true on success.
    @discardableResult
    static func perform(action: String, on element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }

    // MARK: - App element factory

    static func applicationElement(for pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }
}

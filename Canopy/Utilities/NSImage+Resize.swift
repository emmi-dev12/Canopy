import AppKit

extension NSImage {
    /// Returns a copy of the image resized to `size`, maintaining aspect ratio.
    func resized(to size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: self.size),
            operation: .copy,
            fraction: 1.0
        )
        result.unlockFocus()
        return result
    }

    /// Returns a 16×16 copy suitable for dense list rows.
    var smallIcon: NSImage { resized(to: NSSize(width: 16, height: 16)) }

    /// Returns a 20×20 copy suitable for standard list rows.
    var rowIcon: NSImage { resized(to: NSSize(width: 20, height: 20)) }
}

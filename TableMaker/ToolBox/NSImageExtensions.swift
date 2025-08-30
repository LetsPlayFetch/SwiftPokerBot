import AppKit

extension NSImage {
    var isValid: Bool {
        return size.width > 0 && size.height > 0 && representations.count > 0
    }
}

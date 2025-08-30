import Foundation
import AppKit

class RGBCardBack {
    func check(in screenshot: NSImage, region: RegionBox) -> Bool {
        guard let avg = ColorUtilities.averageColor(in: screenshot, for: region) else { return false }
        return ColorUtilities.matches(avg, to: NSColor(red: 34/255.0, green: 73/255.0, blue: 134/255.0, alpha: 1.0), tolerance: 0.15)
    }
}

import Foundation
import AppKit

class RGBDealerButton {
    func check(in screenshot: NSImage, region: RegionBox) -> Bool {
        guard let avg = ColorUtilities.averageColor(in: screenshot, for: region) else { return false }
        return ColorUtilities.matches(avg, to: NSColor(red: 233/255, green: 242/255, blue: 237/255, alpha: 1), tolerance: 0.1)
    }
}

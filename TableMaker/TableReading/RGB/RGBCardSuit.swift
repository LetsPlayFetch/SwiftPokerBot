import Foundation
import AppKit

class RGBCardSuit {
    func detect(in screenshot: NSImage, region: RegionBox) -> Suit? {
        guard let avg = ColorUtilities.averageColor(in: screenshot, for: region) else { return nil }
        let comps = ColorUtilities.components(from: avg)
        
        let suitMap: [Suit:(r: CGFloat, g: CGFloat, b: CGFloat)] = [
            .hearts:   (r: 153/255, g: 71/255,  b: 73/255),
            .diamonds: (r: 72/255,  g: 118/255, b: 155/255),
            .clubs:    (r: 79/255,  g: 151/255, b: 86/255),
            .spades:   (r: 102/255, g: 102/255, b: 102/255)
        ]
        
        for (suit, target) in suitMap {
            if abs(comps.r - target.r) <= 0.15 &&
               abs(comps.g - target.g) <= 0.15 &&
               abs(comps.b - target.b) <= 0.15 {
                return suit
            }
        }
        return nil
    }
}

import Foundation
import AppKit
import CoreImage

/// Main RGB service with configurable color targets
struct RGBService {
    var targets: RGBTargets
    var tolerance: Float = 0.10  // 10% tolerance
    
    init(targets: RGBTargets = .default, tolerance: Float = 0.10) {
        self.targets = targets
        self.tolerance = tolerance
    }
    
    // MARK: - Check Functions
    
    func checkDealerButton(in screenshot: NSImage, for region: RegionBox) -> Bool {
        guard let avg = ColorUtilities.averageColor(in: screenshot, for: region) else { return false }
        return ColorUtilities.matches(avg, to: targets.dealerButton.nsColor, tolerance: CGFloat(tolerance))
    }
    
    func checkCardBack(in screenshot: NSImage, for region: RegionBox) -> Bool {
        guard let avg = ColorUtilities.averageColor(in: screenshot, for: region) else { return false }
        return ColorUtilities.matches(avg, to: targets.cardBack.nsColor, tolerance: CGFloat(tolerance))
    }
    
    func detectCardSuit(in screenshot: NSImage, for region: RegionBox) -> Suit? {
        guard let avg = ColorUtilities.averageColor(in: screenshot, for: region) else { return nil }
        let comps = ColorUtilities.components(from: avg)
        
        // Check each suit against its target color
        for (suit, targetColor) in targets.cardSuits {
            let target = targetColor.nsColor
            let targetComps = ColorUtilities.components(from: target)
            
            if abs(comps.r - targetComps.r) <= CGFloat(tolerance) &&
               abs(comps.g - targetComps.g) <= CGFloat(tolerance) &&
               abs(comps.b - targetComps.b) <= CGFloat(tolerance) {
                return suit
            }
        }
        return nil
    }
    
    // MARK: - Test/Debug Functions
    
    /// Get the actual color detected in a region
    func getDetectedColor(in screenshot: NSImage, for region: RegionBox) -> NSColor? {
        return ColorUtilities.averageColor(in: screenshot, for: region)
    }
    
    /// Get color as RGBColor struct
    func getDetectedRGBColor(in screenshot: NSImage, for region: RegionBox) -> RGBColor? {
        guard let nsColor = getDetectedColor(in: screenshot, for: region) else { return nil }
        return RGBColor(nsColor: nsColor)
    }
    
    /// Check if detected color matches target within tolerance
    func testColorMatch(detected: NSColor, target: NSColor) -> (matches: Bool, difference: Float) {
        let d = ColorUtilities.components(from: detected)
        let t = ColorUtilities.components(from: target)
        
        let rDiff = abs(d.r - t.r)
        let gDiff = abs(d.g - t.g)
        let bDiff = abs(d.b - t.b)
        
        let maxDiff = max(rDiff, max(gDiff, bDiff))
        let matches = maxDiff <= CGFloat(tolerance)
        
        return (matches, Float(maxDiff))
    }
}

// MARK: - ColorUtilities (Thread-safe)

struct ColorUtilities {
    private static let ciContext = CIContext()
    private static let ciQueue = DispatchQueue(label: "com.yourapp.colorutilities", qos: .userInitiated)

    static func averageColor(in screenshot: NSImage, for region: RegionBox) -> NSColor? {
        return ciQueue.sync {
            let tiffData: Data? = {
                if Thread.isMainThread {
                    return screenshot.tiffRepresentation
                } else {
                    return DispatchQueue.main.sync { screenshot.tiffRepresentation }
                }
            }()
            
            guard let tiff = tiffData,
                  let baseCIImage = CIImage(data: tiff) else {
                return nil
            }

            let flippedRect = CGRect(
                x: region.rect.origin.x,
                y: baseCIImage.extent.height - region.rect.origin.y - region.rect.height,
                width: region.rect.width,
                height: region.rect.height
            )
            
            let roi = baseCIImage.cropped(to: flippedRect)
            guard let cgRoi = ciContext.createCGImage(roi, from: roi.extent) else {
                return nil
            }
            
            let rep = NSBitmapImageRep(cgImage: cgRoi)
            let w = rep.pixelsWide, h = rep.pixelsHigh
            var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0

            for x in 0..<w {
                for y in 0..<h {
                    guard let color = rep.colorAt(x: x, y: y) else { continue }
                    totalR += color.redComponent
                    totalG += color.greenComponent
                    totalB += color.blueComponent
                }
            }
            
            let count = CGFloat(w * h)
            guard count > 0 else { return nil }
            return NSColor(red: totalR/count, green: totalG/count, blue: totalB/count, alpha: 1.0)
        }
    }

    static func components(from color: NSColor) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        return (rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
    }

    static func matches(_ actual: NSColor, to target: NSColor, tolerance: CGFloat) -> Bool {
        let a = components(from: actual)
        let t = components(from: target)
        return abs(a.r - t.r) <= tolerance &&
               abs(a.g - t.g) <= tolerance &&
               abs(a.b - t.b) <= tolerance
    }

    static func hexString(from color: NSColor) -> String {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

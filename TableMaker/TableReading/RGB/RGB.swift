import Foundation
import AppKit
import CoreImage

/// Main RGB service that coordinates different RGB processors (Thread-safe implementation)
struct RGB {
    private let dealerChecker = RGBDealerButton()
    private let cardBackChecker = RGBCardBack()
    private let suitChecker = RGBCardSuit()
    
    private static let rgbQueue = DispatchQueue(label: "com.morningcoffee.rgb", qos: .userInitiated)
    
    func checkDealerButton(in screenshot: NSImage, for region: RegionBox) -> Bool {
        // RGB operations are fast enough to be synchronous
        return Self.rgbQueue.sync {
            dealerChecker.check(in: screenshot, region: region)
        }
    }
    
    func checkCardBack(in screenshot: NSImage, for region: RegionBox) -> Bool {
        return Self.rgbQueue.sync {
            cardBackChecker.check(in: screenshot, region: region)
        }
    }
    
    func detectCardSuit(in screenshot: NSImage, for region: RegionBox) -> Suit? {
        return Self.rgbQueue.sync {
            suitChecker.detect(in: screenshot, region: region)
        }
    }
}

// MARK: - ColorUtilities.swift 
struct ColorUtilities {
    private static let ciContext = CIContext()
    private static let ciQueue = DispatchQueue(label: "com.yourapp.colorutilities", qos: .userInitiated)

    static func averageColor(in screenshot: NSImage, for region: RegionBox) -> NSColor? {
        //Executing on dedicated queue for thread safety
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

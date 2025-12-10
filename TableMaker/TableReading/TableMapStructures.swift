import Foundation
import AppKit

// MARK: - Main TableMap Container

struct TableMap: Codable, Equatable {
    var regions: [RegionBox]
    var ocrConfigs: OCRConfigs
    var rgbTargets: RGBTargets
}

// MARK: - OCR Configurations

struct OCRConfigs: Codable, Equatable {
    var baseOCR: OCRParameters
    var playerBet: OCRParameters
    var playerBalance: OCRParameters
    var playerAction: OCRParameters
    var tablePot: OCRParameters
}

// MARK: - RGB Target Colors

struct RGBTargets: Codable, Equatable {
    var dealerButton: RGBColor
    var cardBack: RGBColor
    var cardSuits: [Suit: RGBColor]
    
    /// Default RGB targets (current hardcoded values)
    static let `default` = RGBTargets(
        dealerButton: RGBColor(r: 233/255.0, g: 242/255.0, b: 237/255.0),
        cardBack: RGBColor(r: 34/255.0, g: 73/255.0, b: 134/255.0),
        cardSuits: [
            .hearts:   RGBColor(r: 153/255.0, g: 71/255.0,  b: 73/255.0),
            .diamonds: RGBColor(r: 72/255.0,  g: 118/255.0, b: 155/255.0),
            .clubs:    RGBColor(r: 79/255.0,  g: 151/255.0, b: 86/255.0),
            .spades:   RGBColor(r: 102/255.0, g: 102/255.0, b: 102/255.0)
        ]
    )
}

// MARK: - RGB Color

struct RGBColor: Codable, Equatable {
    var r: Float  // 0.0 - 1.0
    var g: Float  // 0.0 - 1.0
    var b: Float  // 0.0 - 1.0
    
    init(r: Float, g: Float, b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }
    
    /// Convert to NSColor
    var nsColor: NSColor {
        return NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
    }
    
    /// Create from NSColor
    init(nsColor: NSColor) {
        let rgb = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        self.r = Float(rgb.redComponent)
        self.g = Float(rgb.greenComponent)
        self.b = Float(rgb.blueComponent)
    }
    
    /// Create from 0-255 values (convenience)
    init(red255: Int, green255: Int, blue255: Int) {
        self.r = Float(red255) / 255.0
        self.g = Float(green255) / 255.0
        self.b = Float(blue255) / 255.0
    }
}

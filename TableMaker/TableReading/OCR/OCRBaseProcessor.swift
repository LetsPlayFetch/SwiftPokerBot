

// MARK: - OCR Parameters Structure MOVED FROM BASEPROCESSOR.swift

struct OCRParameters: Codable, Equatable {
    // Basic parameters
    var scale: Float = 4.0
    var sharpness: Float = 0.4
    var contrast: Float = 1.6
    var brightness: Float = 0.3
    var saturation: Float = 0.0
    var blurRadius: Float = 0.5
    var threshold: Float = 0.25
    var morphRadius: Float = 0.10

    // Color filtering options
    var colorFilterMode: ColorFilterMode = .none
    var hsvHueMin: Float = 60.0
    var hsvHueMax: Float = 180.0
    var hsvSatMin: Float = 0.3
    var hsvSatMax: Float = 1.0
    var colorDistanceThreshold: Float = 0.3
    var whiteBrightnessThreshold: Float = 0.7
    var whiteSaturationMax: Float = 0.2
    
    // Advanced preprocessing options
    var useAdaptiveThreshold: Bool = false
    var adaptiveThresholdBlockSize: Int = 11
    var adaptiveThresholdC: Float = 2.0
    var useBackgroundSubtraction: Bool = false
    var backgroundBlurRadius: Float = 20.0
    var useBilateralFilter: Bool = false
    var bilateralSigmaColor: Float = 75.0
    var bilateralSigmaSpace: Float = 75.0
    var useTextureFilter: Bool = false
    var morphologyMode: MorphologyMode = .none
    var morphologySize: Float = 1.0
    
    static let `default` = OCRParameters()
}

// MARK: - OCR Result Structure

struct OCRResult {
    let text: String?
    let confidence: Float
}

// MARK: - Color Filter Mode Enum

enum ColorFilterMode: String, CaseIterable, Codable {
    case none = "None"
    case hsvFilter = "HSV Filter"
    case colorDistance = "Color Distance"
    case whiteIsolation = "White Isolation"
    case multiChannel = "Multi-Channel"
}

// MARK: - Morphology Mode Enum

/// Morphological operations:
/// - Opening = Erosion + Dilation (remove noise, separates objects)
/// - Closing = Dilation + Erosion (fills holes, connects nearby objects)
/// - Top Hat = Original - Opening (highlights bright details smaller than structuring element)
/// - Black Hat = Closing - Original (highlights dark details smaller than structuring element)
enum MorphologyMode: String, CaseIterable, Codable {
    case none = "None"
    case opening = "Opening"
    case closing = "Closing"
    case topHat = "Top Hat"
    case blackHat = "Black Hat"
}

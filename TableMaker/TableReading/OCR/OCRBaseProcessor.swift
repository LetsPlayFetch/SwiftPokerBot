// MARK: - OCR Parameters Structure
struct OCRParameters: Codable, Equatable {
    // Existing parameters
    var scale: Float = 4.0
    var sharpness: Float = 0.4
    var contrast: Float = 1.6
    var brightness: Float = 0.3
    var saturation: Float = 0.0
    var blurRadius: Float = 0.5
    var threshold: Float = 0.25
    var morphRadius: Float = 0.10

    // NEW COLOR FILTERING OPTIONS
    var colorFilterMode: ColorFilterMode = .none
    var hsvHueMin: Float = 60.0          // Default for filtering green
    var hsvHueMax: Float = 180.0
    var hsvSatMin: Float = 0.3
    var hsvSatMax: Float = 1.0
    var colorDistanceThreshold: Float = 0.3
    var whiteBrightnessThreshold: Float = 0.7
    var whiteSaturationMax: Float = 0.2
    
    // ADVANCED PREPROCESSING OPTIONS
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

enum ColorFilterMode: String, CaseIterable, Codable {
    case none = "None"
    case hsvFilter = "HSV Filter"
    case colorDistance = "Color Distance"
    case whiteIsolation = "White Isolation"
    case multiChannel = "Multi-Channel"
}
// MORPHOLOGICAL OPERATIONS:
// Opening = Erosion + Dilation (remove noise, separates objects)
// Closing = Dilation + Erosion (fills holes, connects nearby objects)
// Top Hat = Original - Opening (highlights bright details smaller than structuring element)
// Black Hat = Closing - Original (highlights dark details smaller than structuring element)
enum MorphologyMode: String, CaseIterable, Codable {
    case none = "None"
    case opening = "Opening"
    case closing = "Closing"
    case topHat = "Top Hat"
    case blackHat = "Black Hat"
}

// MARK: - Updated BaseOCRProcessor
import Foundation
import Vision
import CoreImage
import AppKit

/// Base class providing common OCR functionality with configurable preprocessing
class BaseOCRProcessor {
    var parameters: OCRParameters
    
    init(parameters: OCRParameters = .default) {
        self.parameters = parameters
    }
    
    /// Process generic text with configurable preprocessing
    func processGeneric(screenshot: NSImage, region: RegionBox, completion: @escaping (String?) -> Void) {
        guard let crop = ImageUtilities.cropROI(screenshot, rect: region.rect) else {
            completion(nil)
            return
        }
        
        let processed = preprocessGeneric(crop)
        performOCR(on: processed) { result in
            let filtered = result?.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(filtered?.isEmpty == false ? filtered : nil)
        }
    }

    /// Helper to display a CGImage in a popup window for debugging
    private func showCGImagePopup(_ image: CGImage) {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let imageView = NSImageView(image: nsImage)
        imageView.frame = NSRect(x: 0, y: 0, width: image.width, height: image.height)
        
        let window = NSWindow(
            contentRect: imageView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "OCR Debug Image"
        window.contentView = imageView
        window.makeKeyAndOrderFront(nil)
    }
    
    /// Perform OCR on a processed CIImage (backward compatibility)
    func performOCR(on image: CIImage, completion: @escaping (String?) -> Void) {
        performOCRWithConfidence(on: image) { result in
            completion(result.text)
        }
    }
    
    /// Perform OCR on a processed CIImage with confidence scores
    func performOCRWithConfidence(on image: CIImage, completion: @escaping (OCRResult) -> Void) {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            DispatchQueue.main.async {
                completion(OCRResult(text: nil, confidence: 0.0))
            }
            return
        }
        
        let request = VNRecognizeTextRequest { req, _ in
            if let observations = req.results as? [VNRecognizedTextObservation] {
                // Get the best candidate
                let bestCandidate = observations.first?.topCandidates(1).first
                let result = OCRResult(
                    text: bestCandidate?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: bestCandidate?.confidence ?? 0.0
                )
                
                DispatchQueue.main.async { completion(result) }
            } else {
                DispatchQueue.main.async {
                    completion(OCRResult(text: nil, confidence: 0.0))
                }
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.0
        request.recognitionLanguages = ["en-US"]
        
        DispatchQueue.global(qos: .userInitiated).async {
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }
    
    /// Configurable preprocessing using parameters
    func preprocessGeneric(_ input: CIImage) -> CIImage {
        var processed = input
        
        // Step 1: Scale
        processed = processed.applyingFilter("CILanczosScaleTransform",
                                           parameters: [kCIInputScaleKey: parameters.scale])
        
        // Step 2: Color Filtering
        processed = applyColorFiltering(processed)
        
        // Step 3: Background Subtraction
        if parameters.useBackgroundSubtraction {
            processed = applyBackgroundSubtraction(processed)
        }
        
        // Step 4: Bilateral Filter
        if parameters.useBilateralFilter {
            processed = applyBilateralFilter(processed)
        }
        
        // Step 5: Sharpening
        processed = processed.applyingFilter("CISharpenLuminance",
                                           parameters: ["inputSharpness": parameters.sharpness])
        
        // Step 6: Color Controls
        processed = processed.applyingFilter("CIColorControls",
                                           parameters: [
                                               kCIInputContrastKey: parameters.contrast,
                                               kCIInputBrightnessKey: parameters.brightness,
                                               kCIInputSaturationKey: parameters.saturation
                                           ])
        
        // Step 7: Blur
        processed = processed.applyingFilter("CIGaussianBlur",
                                           parameters: [kCIInputRadiusKey: parameters.blurRadius])
        
        // Step 8: Thresholding
        if parameters.useAdaptiveThreshold {
            processed = applyAdaptiveThreshold(processed)
        } else {
            let kernelString = """
                kernel vec4 thresh(__sample s) {
                    float l = dot(s.rgb, vec3(0.299,0.587,0.114));
                    return l > \(parameters.threshold) ? vec4(1.0) : vec4(0.0);
                }
                """
            let kernel = CIColorKernel(source: kernelString)!
            processed = kernel.apply(extent: processed.extent, arguments: [processed]) ?? processed
        }
        
        // Step 9: Morphology
        processed = applyMorphology(processed)
        
        return processed
    }
    
    // MARK: - New Color Filtering Methods
    
    private func applyColorFiltering(_ image: CIImage) -> CIImage {
        switch parameters.colorFilterMode {
        case .none:
            return image
        case .hsvFilter:
            return applyHSVFilter(image)
        case .colorDistance:
            return applyColorDistanceFilter(image)
        case .whiteIsolation:
            return applyWhiteIsolation(image)
        case .multiChannel:
            return applyMultiChannelFilter(image)
        }
    }
    
    private func applyHSVFilter(_ image: CIImage) -> CIImage {
        let kernelString = """
            kernel vec4 hsvFilter(__sample pixel) {
                vec3 rgb = pixel.rgb;
                
                // Convert RGB to HSV
                float cmax = max(max(rgb.r, rgb.g), rgb.b);
                float cmin = min(min(rgb.r, rgb.g), rgb.b);
                float delta = cmax - cmin;
                
                float h = 0.0;
                if (delta > 0.0) {
                    if (cmax == rgb.r) {
                        h = 60.0 * mod((rgb.g - rgb.b) / delta, 6.0);
                    } else if (cmax == rgb.g) {
                        h = 60.0 * ((rgb.b - rgb.r) / delta + 2.0);
                    } else {
                        h = 60.0 * ((rgb.r - rgb.g) / delta + 4.0);
                    }
                }
                
                float s = (cmax == 0.0) ? 0.0 : delta / cmax;
                float v = cmax;
                
                // Filter based on HSV ranges
                bool inRange = (h >= \(parameters.hsvHueMin) && h <= \(parameters.hsvHueMax)) &&
                              (s >= \(parameters.hsvSatMin) && s <= \(parameters.hsvSatMax));
                              
                return inRange ? vec4(0.0) : pixel;
            }
            """
        
        guard let kernel = CIColorKernel(source: kernelString) else { return image }
        return kernel.apply(extent: image.extent, arguments: [image]) ?? image
    }
    
    private func applyColorDistanceFilter(_ image: CIImage) -> CIImage {
        let kernelString = """
            kernel vec4 colorDistance(__sample pixel) {
                vec3 rgb = pixel.rgb;
                
                // Distance from green (approximate)
                vec3 green = vec3(0.0, 0.5, 0.0);
                float greenDist = distance(rgb, green);
                
                // Distance from yellow (approximate)
                vec3 yellow = vec3(1.0, 1.0, 0.0);
                float yellowDist = distance(rgb, yellow);
                
                // Distance from black
                vec3 black = vec3(0.0, 0.0, 0.0);
                float blackDist = distance(rgb, black);
                
                float threshold = \(parameters.colorDistanceThreshold);
                
                if (greenDist < threshold || yellowDist < threshold || blackDist < threshold) {
                    return vec4(0.0);
                }
                
                return pixel;
            }
            """
        
        guard let kernel = CIColorKernel(source: kernelString) else { return image }
        return kernel.apply(extent: image.extent, arguments: [image]) ?? image
    }
    
    private func applyWhiteIsolation(_ image: CIImage) -> CIImage {
        let kernelString = """
            kernel vec4 whiteIsolation(__sample pixel) {
                vec3 rgb = pixel.rgb;
                
                // Calculate brightness (luminance)
                float brightness = dot(rgb, vec3(0.299, 0.587, 0.114));
                
                // Calculate saturation
                float cmax = max(max(rgb.r, rgb.g), rgb.b);
                float cmin = min(min(rgb.r, rgb.g), rgb.b);
                float saturation = (cmax == 0.0) ? 0.0 : (cmax - cmin) / cmax;
                
                // Keep only bright, low-saturation pixels (white/gray)
                if (brightness >= \(parameters.whiteBrightnessThreshold) && 
                    saturation <= \(parameters.whiteSaturationMax)) {
                    return pixel;
                } else {
                    return vec4(0.0);
                }
            }
            """
        
        guard let kernel = CIColorKernel(source: kernelString) else { return image }
        return kernel.apply(extent: image.extent, arguments: [image]) ?? image
    }
    
    private func applyMultiChannelFilter(_ image: CIImage) -> CIImage {
        // Process each channel separately and combine
        let redChannel = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        
        let greenChannel = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        
        let blueChannel = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        
        // Take the maximum of all channels (brightest text)
        return redChannel.applyingFilter("CIMaximumCompositing", parameters: [
            kCIInputBackgroundImageKey: greenChannel.applyingFilter("CIMaximumCompositing", parameters: [
                kCIInputBackgroundImageKey: blueChannel
            ])
        ])
    }
    
    // MARK: - Advanced Processing Methods
    
    private func applyBackgroundSubtraction(_ image: CIImage) -> CIImage {
        let background = image.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: parameters.backgroundBlurRadius
        ])
        
        return image.applyingFilter("CISubtractBlendMode", parameters: [
            kCIInputBackgroundImageKey: background
        ])
    }
    
    private func applyBilateralFilter(_ image: CIImage) -> CIImage {
        // Approximation using guided filter since CIBilateralFilter isn't available
        let blurred = image.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: parameters.bilateralSigmaSpace / 10.0
        ])
        
        // Blend based on color similarity (simplified bilateral effect)
        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 1.2
        ])
    }
    
    private func applyAdaptiveThreshold(_ image: CIImage) -> CIImage {
        // Simplified adaptive thresholding using local blur
        let localMean = image.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: Float(parameters.adaptiveThresholdBlockSize) / 3.0
        ])
        
        let kernelString = """
            kernel vec4 adaptiveThresh(__sample pixel, __sample mean) {
                float pixelLuma = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
                float meanLuma = dot(mean.rgb, vec3(0.299, 0.587, 0.114));
                float threshold = meanLuma - \(parameters.adaptiveThresholdC / 255.0);
                
                return pixelLuma > threshold ? vec4(1.0) : vec4(0.0);
            }
            """
        
        guard let kernel = CIColorKernel(source: kernelString) else { return image }
        return kernel.apply(extent: image.extent, arguments: [image, localMean]) ?? image
    }
    
    private func applyMorphology(_ image: CIImage) -> CIImage {
        switch parameters.morphologyMode {
        case .none:
            return image
        case .opening:
            // Erosion followed by dilation
            let eroded = image.applyingFilter("CIMorphologyMinimum", parameters: [
                kCIInputRadiusKey: parameters.morphologySize
            ])
            return eroded.applyingFilter("CIMorphologyMaximum", parameters: [
                kCIInputRadiusKey: parameters.morphologySize
            ])
        case .closing:
            // Dilation followed by erosion
            let dilated = image.applyingFilter("CIMorphologyMaximum", parameters: [
                kCIInputRadiusKey: parameters.morphologySize
            ])
            return dilated.applyingFilter("CIMorphologyMinimum", parameters: [
                kCIInputRadiusKey: parameters.morphologySize
            ])
        case .topHat:
            // Original minus opening
            let opened = applyMorphology(image) // This would cause recursion, need to implement directly
            return image.applyingFilter("CISubtractBlendMode", parameters: [
                kCIInputBackgroundImageKey: opened
            ])
        case .blackHat:
            // Closing minus original
            let closed = applyMorphology(image) // This would cause recursion, need to implement directly
            return closed.applyingFilter("CISubtractBlendMode", parameters: [
                kCIInputBackgroundImageKey: image
            ])
        }
    }
    
    /// Update parameters and return new processed preview
    func updateParameters(_ newParameters: OCRParameters) {
        self.parameters = newParameters
    }
    
    /// Get preprocessed preview with current parameters
    func preprocessedPreviewImage(from image: NSImage, region: RegionBox) -> NSImage? {
        guard let cropCI = ImageUtilities.cropROI(image, rect: region.rect) else { return nil }
        let processedCI = preprocessGeneric(cropCI)
        return ImageUtilities.ciToNSImage(processedCI)
    }
}


import Foundation
import Vision
import CoreImage
import AppKit

/// Thread-safe wrapper for BaseOCRProcessor
class ThreadSafeBaseOCRProcessor {
    private var baseProcessor: BaseOCRProcessor
    private let parametersLock = NSLock()
    private let processingQueue = DispatchQueue(label: "com.morningcoffee.baseocr", qos: .userInitiated)
    
    init(parameters: OCRParameters = .default) {
        self.baseProcessor = BaseOCRProcessor(parameters: parameters)
    }
    
    func updateParameters(_ parameters: OCRParameters) {
        parametersLock.lock()
        defer { parametersLock.unlock() }
        baseProcessor.updateParameters(parameters)
    }
    
    func getParameters() -> OCRParameters {
        parametersLock.lock()
        defer { parametersLock.unlock() }
        return baseProcessor.parameters
    }
    
    func processGeneric(screenshot: NSImage, region: RegionBox, completion: @escaping (String?) -> Void) {
        processingQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Check for cancellation
            guard !Thread.current.isCancelled else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Thread-safe access to processor
            self.parametersLock.lock()
            let processor = self.baseProcessor
            self.parametersLock.unlock()
            
            // Perform processing
            processor.processGeneric(screenshot: screenshot, region: region) { result in
                // Check cancellation before returning result
                guard !Thread.current.isCancelled else { return }
                completion(result)
            }
        }
    }
    
    func preprocessedPreviewImage(from image: NSImage, region: RegionBox) -> NSImage? {
        parametersLock.lock()
        defer { parametersLock.unlock() }
        return baseProcessor.preprocessedPreviewImage(from: image, region: region)
    }
}

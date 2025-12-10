import Foundation
import Vision
import CoreImage
import AppKit

/// Unified OCR service - handles all OCR types with single processing pipeline
struct OCRService {
    
    // MARK: - Configuration Instances (One per OCR Type)
    
    var baseOCRConfig: OCRParameters
    var playerBetConfig: OCRParameters
    var playerBalanceConfig: OCRParameters
    var playerActionConfig: OCRParameters
    var tablePotConfig: OCRParameters
    
    // MARK: - Bad Match Configuration
    
    private let ocrBadMatchThreshold: Float = 0.80  // Save if confidence < 80%
    private let badOCRDirectory: URL
    
    // MARK: - Operation Queue (Simplified)
    
    private static let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .userInitiated
        queue.name = "OCRService.operationQueue"
        return queue
    }()
    
    // MARK: - Reusable Vision Request (Performance Optimization)
    
    // Thread-safe callback storage
    private static var currentOCRCompletion: ((OCRResult) -> Void)?
    private static let completionLock = NSLock()
    
    private static let ocrRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest { req, _ in
            completionLock.lock()
            let completion = currentOCRCompletion
            completionLock.unlock()
            
            guard let completion = completion else { return }
            
            guard let observations = req.results as? [VNRecognizedTextObservation] else {
                completion(OCRResult(text: nil, confidence: 0.0))
                return
            }
            
            let bestCandidate = observations.first?.topCandidates(1).first
            let result = OCRResult(
                text: bestCandidate?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: bestCandidate?.confidence ?? 0.0
            )
            
            completion(result)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.0
        request.recognitionLanguages = ["en-US"]
        return request
    }()
    
    // MARK: - Initialization
    
    init(baseOCRParameters: OCRParameters = .default) {
        self.baseOCRConfig = baseOCRParameters
        self.playerBetConfig = Self.playerBetDefaults()
        self.playerBalanceConfig = Self.playerBalanceDefaults()
        self.playerActionConfig = Self.playerActionDefaults()
        self.tablePotConfig = Self.tablePotDefaults()
        
        // Initialize bad OCR directory
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let baseDirectory = docs.appendingPathComponent("CardTemplates")
        self.badOCRDirectory = baseDirectory.appendingPathComponent("BadOCR")
        
        print("📁 Bad OCR directory: \(badOCRDirectory.path)")
    }
    
    // MARK: - Default Config Generators
    
    private static func playerBetDefaults() -> OCRParameters {
        return OCRParameters(
            scale: 6.0,
            sharpness: 0.4,
            contrast: 1.5,
            brightness: 0.0,
            saturation: 0.0,
            blurRadius: 2.0,
            threshold: 0.55,
            morphRadius: 0.5,
            colorFilterMode: .hsvFilter,
            hsvHueMin: 60.0,
            hsvHueMax: 180.0,
            hsvSatMin: 0.30,
            hsvSatMax: 1.0,
            colorDistanceThreshold: 0.3,
            whiteBrightnessThreshold: 0.7,
            whiteSaturationMax: 0.2,
            useAdaptiveThreshold: false,
            adaptiveThresholdBlockSize: 11,
            adaptiveThresholdC: 2.0,
            useBackgroundSubtraction: false,
            backgroundBlurRadius: 20.0,
            useBilateralFilter: false,
            bilateralSigmaColor: 75.0,
            bilateralSigmaSpace: 75.0,
            useTextureFilter: false,
            morphologyMode: .none,
            morphologySize: 1.0
        )
    }
    
    private static func playerBalanceDefaults() -> OCRParameters {
        return OCRParameters(
            scale: 4.0,
            sharpness: 0.40,
            contrast: 1.60,
            brightness: 0.30,
            saturation: 0.0,
            blurRadius: 0.50,
            threshold: 0.20,
            morphRadius: 0.10,
            colorFilterMode: .colorDistance,
            hsvHueMin: 60.0,
            hsvHueMax: 180.0,
            hsvSatMin: 0.3,
            hsvSatMax: 1.0,
            colorDistanceThreshold: 0.40,
            whiteBrightnessThreshold: 0.7,
            whiteSaturationMax: 0.2,
            useAdaptiveThreshold: false,
            adaptiveThresholdBlockSize: 11,
            adaptiveThresholdC: 2.0,
            useBackgroundSubtraction: false,
            backgroundBlurRadius: 20.0,
            useBilateralFilter: false,
            bilateralSigmaColor: 75.0,
            bilateralSigmaSpace: 75.0,
            useTextureFilter: false,
            morphologyMode: .none,
            morphologySize: 1.0
        )
    }
    
    private static func playerActionDefaults() -> OCRParameters {
        return OCRParameters(
            scale: 4.0,
            sharpness: 0.40,
            contrast: 1.40,
            brightness: 0.40,
            saturation: 0.0,
            blurRadius: 0.50,
            threshold: 0.50,
            morphRadius: 0.10,
            colorFilterMode: .colorDistance,
            hsvHueMin: 60.0,
            hsvHueMax: 180.0,
            hsvSatMin: 0.3,
            hsvSatMax: 1.0,
            colorDistanceThreshold: 0.40,
            whiteBrightnessThreshold: 0.7,
            whiteSaturationMax: 0.2,
            useAdaptiveThreshold: false,
            adaptiveThresholdBlockSize: 11,
            adaptiveThresholdC: 2.0,
            useBackgroundSubtraction: false,
            backgroundBlurRadius: 20.0,
            useBilateralFilter: false,
            bilateralSigmaColor: 75.0,
            bilateralSigmaSpace: 75.0,
            useTextureFilter: false,
            morphologyMode: .none,
            morphologySize: 1.0
        )
    }
    
    private static func tablePotDefaults() -> OCRParameters {
        return OCRParameters(
            scale: 4.0,
            sharpness: 0.40,
            contrast: 1.60,
            brightness: 0.30,
            saturation: 0.0,
            blurRadius: 0.50,
            threshold: 0.25,
            morphRadius: 0.10,
            colorFilterMode: .colorDistance,
            hsvHueMin: 60.0,
            hsvHueMax: 180.0,
            hsvSatMin: 0.3,
            hsvSatMax: 1.0,
            colorDistanceThreshold: 0.80,
            whiteBrightnessThreshold: 0.7,
            whiteSaturationMax: 0.2,
            useAdaptiveThreshold: false,
            adaptiveThresholdBlockSize: 11,
            adaptiveThresholdC: 2.0,
            useBackgroundSubtraction: false,
            backgroundBlurRadius: 20.0,
            useBilateralFilter: false,
            bilateralSigmaColor: 75.0,
            bilateralSigmaSpace: 75.0,
            useTextureFilter: false,
            morphologyMode: .none,
            morphologySize: 1.0
        )
    }
    
    // MARK: - Parameter Management
    
    mutating func updateConfig(for type: OCRType, parameters: OCRParameters) {
        switch type {
        case .baseOCR:
            baseOCRConfig = parameters
        case .playerBet:
            playerBetConfig = parameters
        case .playerBalance:
            playerBalanceConfig = parameters
        case .playerAction:
            playerActionConfig = parameters
        case .tablePot:
            tablePotConfig = parameters
        }
    }
    
    func getConfig(for type: OCRType) -> OCRParameters {
        switch type {
        case .baseOCR:
            return baseOCRConfig
        case .playerBet:
            return playerBetConfig
        case .playerBalance:
            return playerBalanceConfig
        case .playerAction:
            return playerActionConfig
        case .tablePot:
            return tablePotConfig
        }
    }
    
    // MARK: - Unified OCR Function
    
    /// Universal OCR function - handles all types
    func performOCR(
        type: OCRType,
        screenshot: NSImage,
        region: RegionBox,
        completion: @escaping (NSImage, String) -> Void
    ) {
        // Get the right config
        let config = getConfig(for: type)
        
        // Crop the region
        guard let cropCI = ImageUtilities.cropROI(screenshot, rect: region.rect) else {
            completion(NSImage(), "")
            return
        }
        
        // Preprocess with config
        let processedCI = OCRPreprocessor.preprocess(image: cropCI, config: config)
        let previewImage = ImageUtilities.ciToNSImage(processedCI)
        
        // Perform OCR on background queue
        Self.operationQueue.addOperation {
            self.runVisionOCR(on: processedCI, type: type) { result in
                // Log the result
                print("\(type) OCR - Text: '\(result.text ?? "nil")', Confidence: \(result.confidence)")
                
                // Check if this is a bad match and save it
                if result.confidence < self.ocrBadMatchThreshold {
                    print("⚠️ WARNING: Low OCR confidence (score: \(String(format: "%.2f", result.confidence)))")
                    self.saveBadOCR(
                        processedImage: processedCI,
                        rawText: result.text ?? "",
                        confidence: result.confidence,
                        type: type,
                        region: region
                    )
                }
                
                // Validate based on type
                let validatedText = self.validate(result.text, for: type)
                
                // Return on main queue
                DispatchQueue.main.async {
                    completion(previewImage, validatedText)
                }
            }
        }
    }
    
    // MARK: - Vision OCR
    
    private func runVisionOCR(on image: CIImage, type: OCRType, completion: @escaping (OCRResult) -> Void) {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            completion(OCRResult(text: nil, confidence: 0.0))
            return
        }
        
        // Store the completion handler in thread-safe way
        Self.completionLock.lock()
        Self.currentOCRCompletion = completion
        Self.completionLock.unlock()
        
        // Reuse the static request
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([Self.ocrRequest])
    }
    
    // MARK: - Bad OCR Saving
    
    /// Save bad OCR match for review
    /// Filename format: YYYY-MM-DD_HHmmss_type_conf0.75_rawtext.jpg
    private func saveBadOCR(
        processedImage: CIImage,
        rawText: String,
        confidence: Float,
        type: OCRType,
        region: RegionBox
    ) {
        do {
            try FileManager.default.createDirectory(at: badOCRDirectory, withIntermediateDirectories: true)
            
            // Create timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            
            // Format confidence
            let confStr = String(format: "%.2f", confidence)
            
            // Clean raw text for filename (remove special chars, limit length)
            let cleanedText = rawText
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "")
                .replacingOccurrences(of: "\\", with: "")
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "?", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "|", with: "")
                .prefix(30)  // Limit length to avoid filesystem issues
            
            let textPart = cleanedText.isEmpty ? "empty" : String(cleanedText)
            
            // Get type name
            let typeName = getTypeString(type)
            
            // Build filename: 2025-10-11_143022_playerBet_conf0.75_123BB.jpg
            let filename = "\(timestamp)_\(typeName)_conf\(confStr)_\(textPart).jpg"
            let filePath = badOCRDirectory.appendingPathComponent(filename)
            
            // Convert CIImage to NSImage and save as JPEG
            let nsImage = ImageUtilities.ciToNSImage(processedImage)
            let success = ImageUtilities.saveAsJPEG(nsImage, to: filePath, quality: 0.95)
            
            if success {
                print("💾 Saved bad OCR: \(filename)")
            } else {
                print("❌ Failed to save bad OCR image")
            }
            
        } catch {
            print("❌ Failed to save bad OCR: \(error)")
        }
    }
    
    /// Get string name for OCR type
    private func getTypeString(_ type: OCRType) -> String {
        switch type {
        case .baseOCR:
            return "baseOCR"
        case .playerBet:
            return "playerBet"
        case .playerBalance:
            return "playerBalance"
        case .playerAction:
            return "playerAction"
        case .tablePot:
            return "tablePot"
        }
    }
    
    // MARK: - Validation
    
    private func validate(_ text: String?, for type: OCRType) -> String {
        switch type {
        case .baseOCR:
            return text ?? ""
        case .playerBet:
            return OCRValidation.validatePlayerBet(text)
        case .playerBalance:
            return OCRValidation.validatePlayerBalance(text)
        case .playerAction:
            return OCRValidation.validatePlayerAction(text)
        case .tablePot:
            return OCRValidation.validateTablePot(text)
        }
    }
    
    // MARK: - Preview Utilities
    
    func croppedImage(in screenshot: NSImage, for region: RegionBox) -> NSImage? {
        return ImageUtilities.croppedImage(in: screenshot, for: region)
    }
    
    func preprocessedImage(in screenshot: NSImage, for region: RegionBox, type: OCRType) -> NSImage? {
        guard let cropCI = ImageUtilities.cropROI(screenshot, rect: region.rect) else { return nil }
        let config = getConfig(for: type)
        let processedCI = OCRPreprocessor.preprocess(image: cropCI, config: config)
        return ImageUtilities.ciToNSImage(processedCI)
    }
    
    func averageColorString(in screenshot: NSImage, for region: RegionBox) -> String? {
        return ImageUtilities.averageColorString(in: screenshot, for: region)
    }
    
    /// Get bad OCR directory for UI "Open Bad OCR" button
    func getBadOCRDirectory() -> URL {
        return badOCRDirectory
    }
    
    // MARK: - Wrapper Functions (Backward Compatibility)
    
    /// Read player bet - wrapper for performOCR
    func readPlayerBet(in screenshot: NSImage, for region: RegionBox,
                       completion: @escaping (NSImage, String) -> Void) {
        performOCR(type: .playerBet, screenshot: screenshot, region: region, completion: completion)
    }
    
    /// Read player balance - wrapper for performOCR
    func readPlayerBalance(in screenshot: NSImage, for region: RegionBox,
                          completion: @escaping (NSImage, String) -> Void) {
        performOCR(type: .playerBalance, screenshot: screenshot, region: region, completion: completion)
    }
    
    /// Read player action - wrapper for performOCR
    func readPlayerAction(in screenshot: NSImage, for region: RegionBox,
                         completion: @escaping (NSImage, String) -> Void) {
        performOCR(type: .playerAction, screenshot: screenshot, region: region, completion: completion)
    }
    
    /// Read table pot - wrapper for performOCR
    func readTablePot(in screenshot: NSImage, for region: RegionBox,
                      completion: @escaping (NSImage, String) -> Void) {
        performOCR(type: .tablePot, screenshot: screenshot, region: region, completion: completion)
    }
    
    /// Read generic value (baseOCR) - wrapper for performOCR
    func readValue(in screenshot: NSImage, for region: RegionBox,
                   completion: @escaping (String?) -> Void) {
        performOCR(type: .baseOCR, screenshot: screenshot, region: region) { _, text in
            completion(text.isEmpty ? nil : text)
        }
    }
}

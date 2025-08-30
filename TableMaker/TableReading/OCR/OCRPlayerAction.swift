import Foundation
import Vision
import CoreImage
import AppKit

/// Complete player action processing with configurable preprocessing settings
class PlayerActionOCR: BaseOCRProcessor {
    
    struct Constants {
        // Configurable settings for easy tuning
        static let scaleFactor: CGFloat = 4.00
        static let sharpenValue: CGFloat = 0.40
        static let contrastValue: CGFloat = 1.60
        static let brightnessValue: CGFloat = 0.30
        static let saturationValue: CGFloat = 0.0
        static let blurRadius: CGFloat = 0.5
        static let binarizationThreshold: Float = 0.25
        static let morphologyRadius: Float = 0.10
    }
    
    func process(screenshot: NSImage, region: RegionBox, completion: @escaping (NSImage, String) -> Void) {
        guard let cropCI = ImageUtilities.cropROI(screenshot, rect: region.rect) else {
            completion(NSImage(), "")
            return
        }
        
        let processedCI = preprocessPlayerAction(cropCI)
        let previewImage = ImageUtilities.ciToNSImage(processedCI)
        
        performPlayerActionOCRWithConfidence(on: processedCI) { result in
            print("PlayerAction OCR - Text: '\(result.text ?? "nil")', Confidence: \(result.confidence)")
            
            let validatedResult = self.validateAndFormatAction(result.text)
            completion(previewImage, validatedResult)
        }
    }
    
    /// Preprocessing with configurable constants for easy tuning
    private func preprocessPlayerAction(_ input: CIImage) -> CIImage {
        // Step 1: Scale
        let enlarged = input.applyingFilter("CILanczosScaleTransform",
                                            parameters: [kCIInputScaleKey: Constants.scaleFactor])
        
        // Step 2: Sharpening
        let sharpened = enlarged.applyingFilter("CISharpenLuminance",
                                                parameters: ["inputSharpness": Constants.sharpenValue])
        
        // Step 3: Color Controls
        let highContrast = sharpened.applyingFilter("CIColorControls",
                                                    parameters: [
                                                        kCIInputContrastKey: Constants.contrastValue,
                                                        kCIInputBrightnessKey: Constants.brightnessValue,
                                                        kCIInputSaturationKey: Constants.saturationValue
                                                    ])
        
        // Step 4: Blur
        let smoothed = highContrast.applyingFilter("CIGaussianBlur",
                                                   parameters: [kCIInputRadiusKey: Constants.blurRadius])
        
        // Step 5: Binarization Threshold
        let kernelString = """
            kernel vec4 thresh(__sample s) {
                float l = dot(s.rgb, vec3(0.299,0.587,0.114));
                return l > \(Constants.binarizationThreshold) ? vec4(1.0) : vec4(0.0);
            }
            """
        let kernel = CIColorKernel(source: kernelString)!
        let binarized = kernel.apply(extent: smoothed.extent,
                                     arguments: [smoothed]) ?? smoothed
        
        // Step 6: Morphology
        let thickened = binarized.applyingFilter("CIMorphologyMaximum",
                                                 parameters: [kCIInputRadiusKey: Constants.morphologyRadius])
        
        return thickened
    }
    
    /// Perform OCR for player actions with confidence scores
    private func performPlayerActionOCRWithConfidence(on image: CIImage, completion: @escaping (OCRResult) -> Void) {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            DispatchQueue.main.async {
                completion(OCRResult(text: nil, confidence: 0.0))
            }
            return
        }

        let request = VNRecognizeTextRequest { req, _ in
            guard let observations = req.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    completion(OCRResult(text: nil, confidence: 0.0))
                }
                return
            }
            
            // Get best candidate
            let bestCandidate = observations.first?.topCandidates(1).first
            let result = OCRResult(
                text: bestCandidate?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: bestCandidate?.confidence ?? 0.0
            )
            
            DispatchQueue.main.async { completion(result) }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.0
        request.recognitionLanguages = ["en-US"]

        DispatchQueue.global(qos: .userInitiated).async {
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }
    
    /// Validate and format action result
    private func validateAndFormatAction(_ input: String?) -> String {
        guard let input = input?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            return ""
        }
        
        let validActions = ["Check", "Bet", "Call", "Fold", "Raise", "All In", "All-In", "Allin"]
        let upperInput = input.uppercased()
        
        // Direct match (case insensitive)
        for action in validActions {
            if upperInput == action.uppercased() {
                return action
            }
        }
        
        // Partial match for common OCR errors
        if upperInput.contains("CHECK") || upperInput.contains("CHE") {
            return "Check"
        }
        if upperInput.contains("BET") || upperInput.contains("BT") {
            return "Bet"
        }
        if upperInput.contains("CALL") || upperInput.contains("CAL") {
            return "Call"
        }
        if upperInput.contains("FOLD") || upperInput.contains("FOL") {
            return "Fold"
        }
        if upperInput.contains("RAISE") || upperInput.contains("RAS") {
            return "Raise"
        }
        if upperInput.contains("ALL") || upperInput.contains("ALLIN") {
            return "All In"
        }
        
        return input // Return original if no validation matches
    }
    
    override func preprocessedPreviewImage(from image: NSImage, region: RegionBox) -> NSImage {
        guard let cropCI = ImageUtilities.cropROI(image, rect: region.rect) else { return NSImage() }
        let processedCI = preprocessPlayerAction(cropCI)
        return ImageUtilities.ciToNSImage(processedCI)
    }
}

import Foundation
import Vision
import CoreImage
import AppKit

/// Enhanced player balance processing with simple optimized settings
class PlayerBalanceOCR: BaseOCRProcessor {

    struct Constants {
        // Simple hardcoded settings
        static let scaleFactor: CGFloat = 4.0
        static let sharpenValue: CGFloat = 0.40
        static let contrastValue: CGFloat = 1.50
        static let brightnessValue: CGFloat = 0.0
        static let saturationValue: CGFloat = 0.0
        static let blurRadius: CGFloat = 0.50
        static let binarizationThreshold: Float = 0.45
        static let morphologyRadius: Float = 1.0
    }
    
    func process(screenshot: NSImage, region: RegionBox, completion: @escaping (NSImage, String) -> Void) {
        guard let cropCI = ImageUtilities.cropROI(screenshot, rect: region.rect) else {
            completion(NSImage(), "")
            return
        }
        
        let processedCI = preprocessPlayerBalance(cropCI)
        let previewImage = ImageUtilities.ciToNSImage(processedCI)
        
        performPlayerBalanceOCRWithConfidence(on: processedCI) { result in
            print("PlayerBalance OCR - Text: '\(result.text ?? "nil")', Confidence: \(result.confidence)")
            
            let validatedResult = self.validateAndFormatBalance(result.text)
            completion(previewImage, validatedResult)
        }
    }
    
    /// Simple preprocessing with basic settings only
    private func preprocessPlayerBalance(_ input: CIImage) -> CIImage {
        // Step 1: Scale
        let enlarged = input.applyingFilter("CILanczosScaleTransform",
                                            parameters: [kCIInputScaleKey: Constants.scaleFactor])
        
        // Step 2: Sharpening
        let sharpened = enlarged.applyingFilter("CISharpenLuminance",
                                                parameters: ["inputSharpness": Constants.sharpenValue])
        
        // Step 3: Color Controls
        let colorAdjusted = sharpened.applyingFilter("CIColorControls",
                                                    parameters: [
                                                        kCIInputContrastKey: Constants.contrastValue,
                                                        kCIInputBrightnessKey: Constants.brightnessValue,
                                                        kCIInputSaturationKey: Constants.saturationValue
                                                    ])
        
        // Step 4: Blur
        let smoothed = colorAdjusted.applyingFilter("CIGaussianBlur",
                                                   parameters: [kCIInputRadiusKey: Constants.blurRadius])
        
        // Step 5: Simple Threshold
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
    
    /// Perform OCR for player balance with confidence scores
    private func performPlayerBalanceOCRWithConfidence(on image: CIImage, completion: @escaping (OCRResult) -> Void) {
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
    
    /// Validate and format balance result
    private func validateAndFormatBalance(_ input: String?) -> String {
        guard let input = input?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            return ""
        }
        
        let cleaned = input.replacingOccurrences(of: "$", with: "")
                          .replacingOccurrences(of: "£", with: "")
                          .replacingOccurrences(of: "€", with: "")
                          .replacingOccurrences(of: ",", with: "")
                          .replacingOccurrences(of: " ", with: "")
        
        if let _ = Double(cleaned) {
            return cleaned
        }
        
        let corrections: [String: String] = [
            "O": "0", "o": "0", "I": "1", "l": "1",
            "S": "5", "s": "5", "B": "8", "G": "6"
        ]
        
        var corrected = cleaned
        for (wrong, right) in corrections {
            corrected = corrected.replacingOccurrences(of: wrong, with: right)
        }
        
        if let _ = Double(corrected) {
            return corrected
        }
        
        return input
    }
    
    override func preprocessedPreviewImage(from image: NSImage, region: RegionBox) -> NSImage {
        guard let cropCI = ImageUtilities.cropROI(image, rect: region.rect) else { return NSImage() }
        let processedCI = preprocessPlayerBalance(cropCI)
        return ImageUtilities.ciToNSImage(processedCI)
    }
}

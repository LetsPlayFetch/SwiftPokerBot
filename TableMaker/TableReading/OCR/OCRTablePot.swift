import Foundation
import Vision
import CoreImage
import AppKit

/// Complete table pot processing with specialized preprocessing and validation
class TablePotOCR: BaseOCRProcessor {
    
    func process(screenshot: NSImage, region: RegionBox, completion: @escaping (NSImage, String) -> Void) {
        guard let cropCI = ImageUtilities.cropROI(screenshot, rect: region.rect) else {
            completion(NSImage(), "")
            return
        }
        
        let processedCI = preprocessTablePot(cropCI)
        let previewImage = ImageUtilities.ciToNSImage(processedCI)
        
        performTablePotOCRWithConfidence(on: processedCI) { result in
            print("TablePot OCR - Text: '\(result.text ?? "nil")', Confidence: \(result.confidence)")
            
            let validatedResult = self.validateAndFormatPot(result.text)
            completion(previewImage, validatedResult)
        }
    }
    
    /// Preprocessing optimized for table pot
    private func preprocessTablePot(_ input: CIImage) -> CIImage {
        let enlarged = input.applyingFilter("CILanczosScaleTransform",
                                            parameters: [kCIInputScaleKey: 4.0])
        
        let sharpened = enlarged.applyingFilter("CISharpenLuminance",
                                                parameters: ["inputSharpness": 0.45])
        
        let highContrast = sharpened.applyingFilter("CIColorControls",
                                                    parameters: [
                                                        kCIInputContrastKey: 1.6,
                                                        kCIInputBrightnessKey: 0.08,
                                                        kCIInputSaturationKey: 0
                                                    ])
        
        let smoothed = highContrast.applyingFilter("CIGaussianBlur",
                                                   parameters: [kCIInputRadiusKey: 0.5])
        
        let kernelString = """
            kernel vec4 thresh(__sample s) {
                float l = dot(s.rgb, vec3(0.299,0.587,0.114));
                return l > 0.54 ? vec4(1.0) : vec4(0.0);
            }
            """
        let kernel = CIColorKernel(source: kernelString)!
        let binarized = kernel.apply(extent: smoothed.extent,
                                     arguments: [smoothed]) ?? smoothed
        
        let thickened = binarized.applyingFilter("CIMorphologyMaximum",
                                                 parameters: [kCIInputRadiusKey: 1.0])
        return thickened
    }
    
    /// Perform OCR for table pot with confidence scores
    private func performTablePotOCRWithConfidence(on image: CIImage, completion: @escaping (OCRResult) -> Void) {
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
    
    /// Validate and format pot result
    private func validateAndFormatPot(_ input: String?) -> String {
        guard let input = input?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            return ""
        }
        
        // Remove currency symbols and clean up
        let cleaned = input.replacingOccurrences(of: "$", with: "")
                          .replacingOccurrences(of: "£", with: "")
                          .replacingOccurrences(of: "€", with: "")
                          .replacingOccurrences(of: ",", with: "")
                          .replacingOccurrences(of: " ", with: "")
                          .replacingOccurrences(of: "Pot:", with: "")
                          .replacingOccurrences(of: "POT:", with: "")
        
        // Check if it's a valid number
        if let _ = Double(cleaned) {
            return cleaned
        }
        
        // corrections for numbers
        let corrections: [String: String] = [
            "O": "0",
            "o": "0",
            "I": "1",
            "l": "1",
            "S": "5",
            "s": "5",
            "B": "8",
            "G": "6"
        ]
        
        var corrected = cleaned
        for (wrong, right) in corrections {
            corrected = corrected.replacingOccurrences(of: wrong, with: right)
        }
        
        // Validate corrected version
        if let _ = Double(corrected) {
            return corrected
        }
        
        return input // Return original if no validation works
    }
    
    override func preprocessedPreviewImage(from image: NSImage, region: RegionBox) -> NSImage {
        print("TablePotOCR preview hit")
        guard let cropCI = ImageUtilities.cropROI(image, rect: region.rect) else { return NSImage() }
        let processedCI = preprocessTablePot(cropCI) // or whatever's appropriate
        return ImageUtilities.ciToNSImage(processedCI)
    }
}

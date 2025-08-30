import Foundation
import Vision
import CoreImage
import AppKit

/// Enhanced card rank processing with optimized settings and HSV filtering
class CardRankOCR: BaseOCRProcessor {
    
    // Initialize TesseractManager for single character recognition
    private let tesseractManager = TesseractManager(language: "eng")
    
    struct Constants {
        // Updated hardcoded settings from screenshot
        static let scaleFactor: CGFloat = 6.0
        static let sharpenValue: CGFloat = 0.4
        static let contrastValue: CGFloat = 1.5
        static let brightnessValue: CGFloat = 0.0
        static let saturationValue: CGFloat = 0.0
        static let blurRadius: CGFloat = 2.0
        static let binarizationThreshold: Float = 0.55
        static let morphologyRadius: Float = 0.5
        
        // HSV Filter settings
        static let hsvHueMin: Float = 60.0
        static let hsvHueMax: Float = 180.0
        static let hsvSatMin: Float = 0.30
        static let hsvSatMax: Float = 1.0
    }
    
    func process(screenshot: NSImage, region: RegionBox, completion: @escaping (NSImage, String) -> Void) {
        guard let cropCI = ImageUtilities.cropROI(screenshot, rect: region.rect) else {
            completion(NSImage(), "")
            return
        }

        // Primary preprocessing and preview
        let processedCI = preprocessCardRank(cropCI)
        let previewImage = ImageUtilities.ciToNSImage(processedCI)

        // First try Vision-based OCR with confidence
        performCardRankOCRWithConfidence(on: processedCI) { result in
            print("CardRank OCR - Text: '\(result.text ?? "nil")', Confidence: \(result.confidence)")
            
            let validatedResult = self.validateAndFormatCardRank(result.text)
            if !validatedResult.isEmpty {
                completion(previewImage, validatedResult)
                return
            }

            // Main OCR failed, backup Tesseract
            print("Main OCR failed, trying backup Tesseract single character recognition")
            self.performFallbackTesseractOCR(on: processedCI) { tesseractResult in
                let final = self.validateAndFormatCardRank(tesseractResult.text)
                completion(previewImage, final)
            }
        }
    }
    
    /// Preprocessing with hardcoded optimized settings and HSV filtering
    private func preprocessCardRank(_ input: CIImage) -> CIImage {
        // Step 1: Scale
        let enlarged = input.applyingFilter("CILanczosScaleTransform",
                                            parameters: [kCIInputScaleKey: Constants.scaleFactor])
        
        // Step 2: HSV Color Filtering (remove green/yellow chips)
        let colorFiltered = applyHSVFilter(enlarged)
        
        // Step 3: Sharpening
        let sharpened = colorFiltered.applyingFilter("CISharpenLuminance",
                                                parameters: ["inputSharpness": Constants.sharpenValue])
        
        // Step 4: Color Controls
        let colorAdjusted = sharpened.applyingFilter("CIColorControls",
                                                    parameters: [
                                                        kCIInputContrastKey: Constants.contrastValue,
                                                        kCIInputBrightnessKey: Constants.brightnessValue,
                                                        kCIInputSaturationKey: Constants.saturationValue
                                                    ])
        
        // Step 5: Blur
        let smoothed = colorAdjusted.applyingFilter("CIGaussianBlur",
                                                   parameters: [kCIInputRadiusKey: Constants.blurRadius])
        
        // Step 6: Thresholding
        let kernelString = """
            kernel vec4 thresh(__sample s) {
                float l = dot(s.rgb, vec3(0.299,0.587,0.114));
                return l > \(Constants.binarizationThreshold) ? vec4(1.0) : vec4(0.0);
            }
            """
        let kernel = CIColorKernel(source: kernelString)!
        let binarized = kernel.apply(extent: smoothed.extent,
                                     arguments: [smoothed]) ?? smoothed
        
        // Step 7: Morphology
        let thickened = binarized.applyingFilter("CIMorphologyMaximum",
                                                 parameters: [kCIInputRadiusKey: Constants.morphologyRadius])
        
        return thickened
    }
    
    /// Apply HSV filtering to remove green/yellow chip colors
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
                
                // Filter based on HSV ranges (remove green/yellow)
                bool inRange = (h >= \(Constants.hsvHueMin) && h <= \(Constants.hsvHueMax)) &&
                              (s >= \(Constants.hsvSatMin) && s <= \(Constants.hsvSatMax));
                              
                return inRange ? vec4(0.0) : pixel;
            }
            """
        
        guard let kernel = CIColorKernel(source: kernelString) else { return image }
        return kernel.apply(extent: image.extent, arguments: [image]) ?? image
    }
    
    // Simplified validation - just clean and uppercase
    private func validateAndFormatCardRank(_ input: String?) -> String {
        guard let input = input?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !input.isEmpty else {
            return ""
        }
        
        // Clean and uppercase the input
        let cleaned = input.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        
        print("OCR raw: '\(input)' -> cleaned: '\(cleaned)'")
        
        // Valid card ranks
        let validRanks = ["A", "K", "Q", "J", "T", "9", "8", "7", "6", "5", "4", "3", "2"]
        
        // Direct match
        if validRanks.contains(cleaned) {
            return cleaned
        }
        
        // Basic character corrections for common OCR mistakes
        let corrections: [String: String] = [
            //"0": "Q",  // 0 sometimes reads as Q
            "10": "T", // 
            "B": "8",  // B can be 8
            "S": "5",  // S can be 5
            "I": "1",  // I can be 1
            "|": "1",  // Pipe can be 1
            "L": "1",  // L can be 1
            //"O": "Q"   // O can be Q
        ]
        
        if let corrected = corrections[cleaned] {
            print("Applied correction: \(cleaned) -> \(corrected)")
            return corrected
        }
        
        print("No valid rank found for: \(cleaned)")
        return cleaned  // Return cleaned result for debugging
    }
    
    /// Perform OCR limited to card ranks with confidence scores
    private func performCardRankOCRWithConfidence(on image: CIImage, completion: @escaping (OCRResult) -> Void) {
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
            
            let validRanks = ["A","K","Q","J","T","9","8","7","6","5","4","3","2"]
            
            // Find best valid rank from all observations
            for observation in observations {
                for candidate in observation.topCandidates(3) {
                    let text = candidate.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased()
                    if validRanks.contains(text) {
                        let result = OCRResult(text: text, confidence: candidate.confidence)
                        DispatchQueue.main.async { completion(result) }
                        return
                    }
                }
            }
            
            // Fallback to first result if no valid rank found
            let firstResult = observations.first?.topCandidates(1).first
            let result = OCRResult(
                text: firstResult?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: firstResult?.confidence ?? 0.0
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
    
    private func performFallbackTesseractOCR(on image: CIImage, completion: @escaping (OCRResult) -> Void) {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            DispatchQueue.main.async {
                completion(OCRResult(text: nil, confidence: 0.0))
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.tesseractManager.getPlayerBet(from: cgImage) //TEMP CALL MAKE REAL FUNC LATER 
            
            // Add this print statement
            print("Tesseract Backup OCR - Text: '\(result.text ?? "nil")', Confidence: \(result.confidence)")
            
            DispatchQueue.main.async {
                completion(OCRResult(text: result.text, confidence: result.confidence))
            }
        }
    }
    
    override func preprocessedPreviewImage(from image: NSImage, region: RegionBox) -> NSImage {
        guard let cropCI = ImageUtilities.cropROI(image, rect: region.rect) else { return NSImage() }
        let processedCI = preprocessCardRank(cropCI)
        return ImageUtilities.ciToNSImage(processedCI)
    }
}

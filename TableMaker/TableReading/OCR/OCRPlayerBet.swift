import Foundation
import Vision
import CoreImage
import AppKit

/// Enhanced player bet processing with Tesseract OCR and optimized settings
class PlayerBetOCR: BaseOCRProcessor {
    

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
        
        let processedCI = preprocessPlayerBet(cropCI)
        let previewImage = ImageUtilities.ciToNSImage(processedCI)
        
        performPlayerBetOCRWithTesseract(on: processedCI) { result in
            print("PlayerBet OCR (Tesseract) - Text: '\(result.text ?? "nil")', Confidence: \(result.confidence)")
            
            let validatedResult = self.validateAndFormatBet(result.text)
            completion(previewImage, validatedResult)
        }
    }
    
    /// Preprocessing with hardcoded optimized settings and HSV filtering
    private func preprocessPlayerBet(_ input: CIImage) -> CIImage {
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
    
    /// Perform OCR for player bet amounts using Apple's Vision framework
    private func performPlayerBetOCRWithTesseract(on image: CIImage, completion: @escaping (OCRResult) -> Void) {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            DispatchQueue.main.async {
                completion(OCRResult(text: nil, confidence: 0.0))
            }
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    completion(OCRResult(text: nil, confidence: 0.0))
                }
                return
            }
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let topCandidate = observations.first?.topCandidates(1).first
            let recognizedText = topCandidate?.string
            let confidence = topCandidate?.confidence ?? 0.0
            DispatchQueue.main.async {
                completion(OCRResult(text: recognizedText, confidence: confidence))
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en_US"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    /// Validate and format bet amount result
    private func validateAndFormatBet(_ input: String?) -> String {
        guard let input = input?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            return ""
        }
        
        return input // 
    }
    
    override func preprocessedPreviewImage(from image: NSImage, region: RegionBox) -> NSImage {
        guard let cropCI = ImageUtilities.cropROI(image, rect: region.rect) else { return NSImage() }
        let processedCI = preprocessPlayerBet(cropCI)
        return ImageUtilities.ciToNSImage(processedCI)
    }
}

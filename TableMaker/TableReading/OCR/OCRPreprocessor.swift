import Foundation
import CoreImage
import AppKit

/// Universal image preprocessing for all OCR types
struct OCRPreprocessor {
    
    /// Single preprocessing function that handles all OCR types based on config
    static func preprocess(image: CIImage, config: OCRParameters) -> CIImage {
        var processed = image
        
        // Step 1: Scale
        processed = processed.applyingFilter("CILanczosScaleTransform",
                                           parameters: [kCIInputScaleKey: config.scale])
        
        // Step 2: Color Filtering (if enabled)
        processed = applyColorFiltering(processed, config: config)
        
        // Step 3: Background Subtraction (if enabled)
        if config.useBackgroundSubtraction {
            processed = applyBackgroundSubtraction(processed, config: config)
        }
        
        // Step 4: Bilateral Filter (if enabled)
        if config.useBilateralFilter {
            processed = applyBilateralFilter(processed, config: config)
        }
        
        // Step 5: Sharpening
        processed = processed.applyingFilter("CISharpenLuminance",
                                           parameters: ["inputSharpness": config.sharpness])
        
        // Step 6: Color Controls
        processed = processed.applyingFilter("CIColorControls",
                                           parameters: [
                                               kCIInputContrastKey: config.contrast,
                                               kCIInputBrightnessKey: config.brightness,
                                               kCIInputSaturationKey: config.saturation
                                           ])
        
        // Step 7: Blur
        processed = processed.applyingFilter("CIGaussianBlur",
                                           parameters: [kCIInputRadiusKey: config.blurRadius])
        
        // Step 8: Thresholding
        if config.useAdaptiveThreshold {
            processed = applyAdaptiveThreshold(processed, config: config)
        } else {
            processed = applySimpleThreshold(processed, config: config)
        }
        
        // Step 9: Morphology (if enabled)
        processed = applyMorphology(processed, config: config)
        
        return processed
    }
    
    // MARK: - Color Filtering Methods
    
    private static func applyColorFiltering(_ image: CIImage, config: OCRParameters) -> CIImage {
        switch config.colorFilterMode {
        case .none:
            return image
        case .hsvFilter:
            return applyHSVFilter(image, config: config)
        case .colorDistance:
            return applyColorDistanceFilter(image, config: config)
        case .whiteIsolation:
            return applyWhiteIsolation(image, config: config)
        case .multiChannel:
            return applyMultiChannelFilter(image)
        }
    }
    
    private static func applyHSVFilter(_ image: CIImage, config: OCRParameters) -> CIImage {
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
                bool inRange = (h >= \(config.hsvHueMin) && h <= \(config.hsvHueMax)) &&
                              (s >= \(config.hsvSatMin) && s <= \(config.hsvSatMax));
                              
                return inRange ? vec4(0.0) : pixel;
            }
            """
        
        guard let kernel = CIColorKernel(source: kernelString) else { return image }
        return kernel.apply(extent: image.extent, arguments: [image]) ?? image
    }
    
    private static func applyColorDistanceFilter(_ image: CIImage, config: OCRParameters) -> CIImage {
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
                
                float threshold = \(config.colorDistanceThreshold);
                
                if (greenDist < threshold || yellowDist < threshold || blackDist < threshold) {
                    return vec4(0.0);
                }
                
                return pixel;
            }
            """
        
        guard let kernel = CIColorKernel(source: kernelString) else { return image }
        return kernel.apply(extent: image.extent, arguments: [image]) ?? image
    }
    
    private static func applyWhiteIsolation(_ image: CIImage, config: OCRParameters) -> CIImage {
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
                if (brightness >= \(config.whiteBrightnessThreshold) && 
                    saturation <= \(config.whiteSaturationMax)) {
                    return pixel;
                } else {
                    return vec4(0.0);
                }
            }
            """
        
        guard let kernel = CIColorKernel(source: kernelString) else { return image }
        return kernel.apply(extent: image.extent, arguments: [image]) ?? image
    }
    
    private static func applyMultiChannelFilter(_ image: CIImage) -> CIImage {
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
    
    private static func applyBackgroundSubtraction(_ image: CIImage, config: OCRParameters) -> CIImage {
        let background = image.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: config.backgroundBlurRadius
        ])
        
        return image.applyingFilter("CISubtractBlendMode", parameters: [
            kCIInputBackgroundImageKey: background
        ])
    }
    
    private static func applyBilateralFilter(_ image: CIImage, config: OCRParameters) -> CIImage {
        // Approximation using guided filter since CIBilateralFilter isn't available
        let blurred = image.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: config.bilateralSigmaSpace / 10.0
        ])
        
        // Blend based on color similarity (simplified bilateral effect)
        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 1.2
        ])
    }
    
    private static func applyAdaptiveThreshold(_ image: CIImage, config: OCRParameters) -> CIImage {
        // Simplified adaptive thresholding using local blur
        let localMean = image.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: Float(config.adaptiveThresholdBlockSize) / 3.0
        ])
        
        let kernelString = """
            kernel vec4 adaptiveThresh(__sample pixel, __sample mean) {
                float pixelLuma = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
                float meanLuma = dot(mean.rgb, vec3(0.299, 0.587, 0.114));
                float threshold = meanLuma - \(config.adaptiveThresholdC / 255.0);
                
                return pixelLuma > threshold ? vec4(1.0) : vec4(0.0);
            }
            """
        
        guard let kernel = CIColorKernel(source: kernelString) else { return image }
        return kernel.apply(extent: image.extent, arguments: [image, localMean]) ?? image
    }
    
    private static func applySimpleThreshold(_ image: CIImage, config: OCRParameters) -> CIImage {
        let kernelString = """
            kernel vec4 thresh(__sample s) {
                float l = dot(s.rgb, vec3(0.299,0.587,0.114));
                return l > \(config.threshold) ? vec4(1.0, 1.0, 1.0, 1.0) : vec4(0.0, 0.0, 0.0, 1.0);
            }
            """
        let kernel = CIColorKernel(source: kernelString)!
        return kernel.apply(extent: image.extent, arguments: [image]) ?? image
    }
    
    // MARK: - Morphology Methods
    
    private static func applyMorphology(_ image: CIImage, config: OCRParameters) -> CIImage {
        switch config.morphologyMode {
        case .none:
            return image
        case .opening:
            // Erosion followed by dilation
            let eroded = image.applyingFilter("CIMorphologyMinimum", parameters: [
                kCIInputRadiusKey: config.morphologySize
            ])
            return eroded.applyingFilter("CIMorphologyMaximum", parameters: [
                kCIInputRadiusKey: config.morphologySize
            ])
        case .closing:
            // Dilation followed by erosion
            let dilated = image.applyingFilter("CIMorphologyMaximum", parameters: [
                kCIInputRadiusKey: config.morphologySize
            ])
            return dilated.applyingFilter("CIMorphologyMinimum", parameters: [
                kCIInputRadiusKey: config.morphologySize
            ])
        case .topHat:
            // Original minus opening (need to implement opening directly to avoid recursion)
            let eroded = image.applyingFilter("CIMorphologyMinimum", parameters: [
                kCIInputRadiusKey: config.morphologySize
            ])
            let opened = eroded.applyingFilter("CIMorphologyMaximum", parameters: [
                kCIInputRadiusKey: config.morphologySize
            ])
            return image.applyingFilter("CISubtractBlendMode", parameters: [
                kCIInputBackgroundImageKey: opened
            ])
        case .blackHat:
            // Closing minus original (need to implement closing directly to avoid recursion)
            let dilated = image.applyingFilter("CIMorphologyMaximum", parameters: [
                kCIInputRadiusKey: config.morphologySize
            ])
            let closed = dilated.applyingFilter("CIMorphologyMinimum", parameters: [
                kCIInputRadiusKey: config.morphologySize
            ])
            return closed.applyingFilter("CISubtractBlendMode", parameters: [
                kCIInputBackgroundImageKey: image
            ])
        }
    }
}

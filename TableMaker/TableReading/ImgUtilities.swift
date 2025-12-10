import Foundation
import CoreImage
import AppKit
import UniformTypeIdentifiers

/// Centralized image processing utilities
struct ImageUtilities {
    private static let ciContext = CIContext()
    
    // MARK: - Core Image Operations
    
    /// Crop the region out of the full screenshot
    static func cropROI(_ image: NSImage, rect: CGRect) -> CIImage? {
        guard let tiff = image.tiffRepresentation,
              let ciImage = CIImage(data: tiff) else { return nil }
        
        // Core Image coordinates use (0,0) at bottom-left.
        // RegionBox.rect comes in **window space** with origin at top-left,
        // so flip the Y-axis:
        let flipped = CGRect(
            x: rect.origin.x,
            y: ciImage.extent.height - rect.origin.y - rect.size.height,
            width: rect.size.width,
            height: rect.size.height
        )
        
        // Clamp to bounds just in case
        let roi = ciImage.extent.intersection(flipped)
        return roi.isNull ? nil : ciImage.cropped(to: roi)
    }
    
    /// Convert CIImage to NSImage
    static func ciToNSImage(_ ciImage: CIImage) -> NSImage {
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
    
    /// Returns the cropped region as an NSImage
    static func croppedImage(in screenshot: NSImage, for region: RegionBox) -> NSImage? {
        guard let cropCI = cropROI(screenshot, rect: region.rect) else { return nil }
        return ciToNSImage(cropCI)
    }
    
    // MARK: - Image Format Conversions
    
    /// Convert NSImage to JPEG data
    static func jpegData(from image: NSImage, compressionQuality: CGFloat = 0.8) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmap.representation(using: .jpeg, properties: [
            .compressionFactor: compressionQuality
        ])
    }
    
    /// Convert NSImage to PNG data
    static func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmap.representation(using: .png, properties: [:])
    }
    
    /// Convert NSImage to TIFF data (existing functionality preserved)
    static func tiffData(from image: NSImage) -> Data? {
        return image.tiffRepresentation
    }
    
    /// Save NSImage as JPEG to file (automatically scales 4x for better quality)
    static func saveAsJPEG(_ image: NSImage, to url: URL, quality: CGFloat = 0.8) -> Bool {
        // Scale 4x for better quality
        let scaledImage = scaleImage(image, by: 4.0)
        
        guard let data = jpegData(from: scaledImage, compressionQuality: quality) else {
            return false
        }
        
        do {
            try data.write(to: url)
            return true
        } catch {
            print("Failed to save JPEG: \(error)")
            return false
        }
    }
    
    /// Save NSImage as PNG to file
    static func saveAsPNG(_ image: NSImage, to url: URL) -> Bool {
        guard let data = pngData(from: image) else {
            return false
        }
        
        do {
            try data.write(to: url)
            return true
        } catch {
            print("Failed to save PNG: \(error)")
            return false
        }
    }
    
    /// Save NSImage as TIFF to file (existing functionality preserved)
    static func saveAsTIFF(_ image: NSImage, to url: URL) -> Bool {
        guard let data = tiffData(from: image) else {
            return false
        }
        
        do {
            try data.write(to: url)
            return true
        } catch {
            print("Failed to save TIFF: \(error)")
            return false
        }
    }
    
    // MARK: - Image Scaling
    
    /// Scale NSImage by a factor using high-quality Lanczos transform
    static func scaleImage(_ image: NSImage, by scaleFactor: CGFloat) -> NSImage {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            print("⚠️ Warning: Could not convert to CIImage for scaling, using original")
            return image
        }
        
        // Apply scaling using high-quality Lanczos transform
        let scaledCI = ciImage.applyingFilter("CILanczosScaleTransform",
                                             parameters: [kCIInputScaleKey: scaleFactor])
        
        let scaledImage = ciToNSImage(scaledCI)
        print("✅ Scaled image from \(image.size) to \(scaledImage.size)")
        return scaledImage
    }
    
    /// Resize NSImage to exact dimensions using high-quality scaling
    static func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            return nil
        }
        
        // Calculate scale factors
        let scaleX = size.width / ciImage.extent.width
        let scaleY = size.height / ciImage.extent.height
        
        // Apply scale transform
        let scaledImage = ciImage.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: max(scaleX, scaleY)  // Use max to maintain aspect ratio initially
        ])
        
        // Crop to exact size if needed
        let finalImage: CIImage
        if scaledImage.extent.width != size.width || scaledImage.extent.height != size.height {
            let cropRect = CGRect(
                x: (scaledImage.extent.width - size.width) / 2,
                y: (scaledImage.extent.height - size.height) / 2,
                width: size.width,
                height: size.height
            )
            finalImage = scaledImage.cropped(to: cropRect)
        } else {
            finalImage = scaledImage
        }
        
        return ciToNSImage(finalImage)
    }
    
    // MARK: - Color Analysis
    
    /// Returns the average color of the cropped region as a hex string
    static func averageColorString(in screenshot: NSImage, for region: RegionBox) -> String? {
        guard let crop = cropROI(screenshot, rect: region.rect) else { return nil }
        
        // Convert to NSBitmapImageRep for pixel analysis
        guard let cgImage = ciContext.createCGImage(crop, from: crop.extent) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        var rTotal: CGFloat = 0, gTotal: CGFloat = 0, bTotal: CGFloat = 0
        
        for x in 0..<width {
            for y in 0..<height {
                guard let c = rep.colorAt(x: x, y: y) else { continue }
                rTotal += c.redComponent
                gTotal += c.greenComponent
                bTotal += c.blueComponent
            }
        }
        
        let pixelCount = CGFloat(width * height)
        guard pixelCount > 0 else { return nil }
        
        let rAvg = Int((rTotal / pixelCount) * 255)
        let gAvg = Int((gTotal / pixelCount) * 255)
        let bAvg = Int((bTotal / pixelCount) * 255)
        
        return String(format: "#%02X%02X%02X", rAvg, gAvg, bAvg)
    }
    
    // MARK: - Color Space Conversion
    
    /// Convert NSImage to sRGB color space
    static func convertToSRGB(_ image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Create sRGB color space
        guard let srgbColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        
        // Create context with sRGB color space
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: srgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        // Draw the image into the sRGB context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        // Create new CGImage from context
        guard let srgbCGImage = context.makeImage() else {
            return nil
        }
        
        return NSImage(cgImage: srgbCGImage, size: image.size)
    }
    
    // MARK: - Image Validation
    
    /// Check if NSImage is valid
    static func isValid(_ image: NSImage) -> Bool {
        return image.size.width > 0 && image.size.height > 0 && image.representations.count > 0
    }
}

// MARK: - NSImage Extensions
extension NSImage {
    /// Convenience property for validation
    var isValid: Bool {
        return ImageUtilities.isValid(self)
    }
    
    /// Convenience method for JPEG data
    func jpegData(quality: CGFloat = 0.8) -> Data? {
        return ImageUtilities.jpegData(from: self, compressionQuality: quality)
    }
    
    /// Convenience method for PNG data
    func pngData() -> Data? {
        return ImageUtilities.pngData(from: self)
    }
    
    /// Convenience method for scaling
    func scaled(by factor: CGFloat) -> NSImage {
        return ImageUtilities.scaleImage(self, by: factor)
    }
}

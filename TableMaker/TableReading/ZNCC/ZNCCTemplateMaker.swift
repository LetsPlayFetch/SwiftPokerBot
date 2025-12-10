import Foundation
import CoreImage
import AppKit
import Accelerate

// MARK: - Template Creation
enum ZNCCTemplateMaker {
    /// Create template from preprocessed NSImage
    static func createTemplate(
        from nsImage: NSImage,
        targetSize: CGSize = CGSize(width: 35, height: 50),
        id: String,
        label: String,
        threshold: Float = 0.70  // Updated default threshold
    ) -> ZNCCTemplate? {
        
        print("🔨 Creating template for label: \(label)")
        
        guard let cgImage = ZNCCPrep.cgImage(from: nsImage) else {
            print("❌ Failed to convert to CGImage")
            return nil
        }
        
        let w = Int(targetSize.width), h = Int(targetSize.height)
        print("📏 Template size: \(w)x\(h)")
        
        // Convert to grayscale floats [0..1]
        var floats = ZNCCPrep.grayscaleFloat(from: cgImage, width: w, height: h)
        print("🎨 Converted to grayscale floats, pixel count: \(floats.count)")
        
        // Calculate mean
        var mean: Float = 0
        vDSP_meanv(floats, 1, &mean, vDSP_Length(floats.count))
        print("📊 Calculated mean: \(String(format: "%.3f", mean))")
        
        // Subtract mean (zero-mean template)
        var zeroMean = floats
        var negMean = -mean
        vDSP_vsadd(floats, 1, &negMean, &zeroMean, 1, vDSP_Length(floats.count))
        
        // Calculate standard deviation
        var variance: Float = 0
        vDSP_measqv(zeroMean, 1, &variance, vDSP_Length(zeroMean.count))
        let sigma = sqrtf(variance)
        print("📈 Calculated sigma: \(String(format: "%.6f", sigma))")
        
        // Avoid templates with no variation
        guard sigma > 1e-6 else {
            print("❌ Template has no variation (sigma too low: \(sigma))")
            return nil
        }
        
        print("✅ Template created successfully: \(label) (sigma: \(String(format: "%.6f", sigma)))")
        
        return ZNCCTemplate(
            id: id,
            label: label,
            w: w, h: h,
            zeroMean: zeroMean,
            sigma: sigma,
            threshold: threshold
        )
    }
}

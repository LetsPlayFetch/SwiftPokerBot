import Foundation
import AppKit

class TrainingDataSaver {
    private let manager = TrainingDataManager.shared
    
    func saveTrainingSample(_ sample: Trainingsample) -> Bool {
        print("🔄 Starting to save training sample...")
        print("   OCR Type: \(sample.ocrType)")
        print("   Label: '\(sample.correctLabel)'")
        print("   Region: \(sample.regionName)")
        
        // First, validate directories
        let validation = manager.validateDirectories()
        if !validation.success {
            print("❌ Directory validation failed: \(validation.message)")
            return false
        }
        print("✅ Directory validation passed")
        
        let directoryURL = manager.getDirectoryURL(for: sample.ocrType)
        let imageFilename = sample.generateFilename()
        let gtFilename = sample.generateGroundTruthFilename()
        
        let imageURL = directoryURL.appendingPathComponent(imageFilename)
        let gtURL = directoryURL.appendingPathComponent(gtFilename)
        
        print("   Image will be saved to: \(imageURL.path)")
        print("   Ground truth will be saved to: \(gtURL.path)")
        
        do {
            // Check if the processed image is valid
            guard sample.processedImage.isValid else {
                print("❌ Error: Processed image is not valid")
                return false
            }
            
            // Try to get TIFF representation
            guard let tiffData = sample.processedImage.tiffRepresentation else {
                print("❌ Error: Could not convert image to TIFF representation")
                return false
            }
            print("✅ Successfully converted image to TIFF (\(tiffData.count) bytes)")
            
            // Save the processed image as TIFF
            try tiffData.write(to: imageURL)
            print("✅ Successfully wrote image file")
            
            // Verify the image file was written
            guard FileManager.default.fileExists(atPath: imageURL.path) else {
                print("❌ Error: Image file was not created at expected location")
                return false
            }
            
            // Save the ground truth text file
            try sample.correctLabel.write(to: gtURL, atomically: true, encoding: .utf8)
            print("✅ Successfully wrote ground truth file")
            
            // Verify the ground truth file was written
            guard FileManager.default.fileExists(atPath: gtURL.path) else {
                print("❌ Error: Ground truth file was not created at expected location")
                return false
            }
            
            // Final verification - try to read back the ground truth
            let readBackLabel = try String(contentsOf: gtURL, encoding: .utf8)
            guard readBackLabel == sample.correctLabel else {
                print("❌ Error: Ground truth file content doesn't match original label")
                print("   Original: '\(sample.correctLabel)'")
                print("   Read back: '\(readBackLabel)'")
                return false
            }
            
            print("🎉 Training sample saved successfully!")
            print("   Final image path: \(imageURL.path)")
            print("   Final ground truth path: \(gtURL.path)")
            
            return true
            
        } catch let error as NSError {
            print("❌ Error saving training sample:")
            print("   Error domain: \(error.domain)")
            print("   Error code: \(error.code)")
            print("   Error description: \(error.localizedDescription)")
            print("   Error failure reason: \(error.localizedFailureReason ?? "Unknown")")
            print("   Error recovery suggestion: \(error.localizedRecoverySuggestion ?? "None")")
            
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   Underlying error: \(underlyingError.localizedDescription)")
            }
            
            return false
        }
    }
    
    // Get existing samples for a specific OCR type
    func getExistingSamples(for ocrType: OCRType) -> [String] {
        let directoryURL = manager.getDirectoryURL(for: ocrType)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            let tiffFiles = files.filter { $0.pathExtension == "tiff" }.map { $0.lastPathComponent }
            print("Found \(tiffFiles.count) existing training samples for \(ocrType)")
            return tiffFiles
        } catch {
            print("Error reading training directory for \(ocrType): \(error)")
            return []
        }
    }
    
    // Check if a label already exists for this OCR type
    func labelExists(_ label: String, for ocrType: OCRType) -> Bool {
        let samples = getExistingSamples(for: ocrType)
        let cleanLabel = label.replacingOccurrences(of: " ", with: "_")
        
        let exists = samples.contains { filename in
            filename.contains("_\(label)_") || filename.contains("_\(cleanLabel)_")
        }
        
        if exists {
            print("Label '\(label)' already exists for \(ocrType)")
        }
        
        return exists
    }
}

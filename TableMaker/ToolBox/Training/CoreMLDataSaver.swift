import Foundation
import AppKit

class CoreMLDataSaver {
    private let manager = CoreMLDataManager.shared
    
    func saveCoreMlSample(_ sample: CoreMLSample) -> Bool {
        print("🔄 Starting to save CoreML sample...")
        print("   Label: '\(sample.label)'")
        print("   Region: \(sample.regionName)")
        
        // First, validate directories
        let validation = manager.validateDirectories()
        if !validation.success {
            print("❌ CoreML directory validation failed: \(validation.message)")
            return false
        }
        print("✅ CoreML directory validation passed")
        
        do {
            // Create label directory if it doesn't exist
            try manager.createLabelDirectoryIfNeeded(for: sample.label)
            
            let directoryURL = manager.getDirectoryURL(for: sample.label)
            let imageFilename = sample.generateFilename()
            let imageURL = directoryURL.appendingPathComponent(imageFilename)
            
            print("   CoreML image will be saved to: \(imageURL.path)")
            
            // Check if the raw image is valid
            guard sample.rawImage.isValid else {
                print("❌ Error: Raw image is not valid")
                return false
            }
            
            // Save as JPEG using the new ImageUtilities
            let success = ImageUtilities.saveAsJPEG(sample.rawImage, to: imageURL, quality: 0.9)
            
            if success {
                print("✅ Successfully saved CoreML JPEG file")
                
                // Verify the image file was written
                guard FileManager.default.fileExists(atPath: imageURL.path) else {
                    print("❌ Error: CoreML image file was not created at expected location")
                    return false
                }
                
                print("🎉 CoreML sample saved successfully!")
                print("   Final image path: \(imageURL.path)")
                return true
            } else {
                print("❌ Failed to save CoreML JPEG")
                return false
            }
            
        } catch let error as NSError {
            print("❌ Error saving CoreML sample:")
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
    
    // Get existing samples for a specific label
    func getExistingSamples(for label: String) -> [String] {
        let directoryURL = manager.getDirectoryURL(for: label)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            let jpegFiles = files.filter { 
                $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" 
            }.map { $0.lastPathComponent }
            
            print("Found \(jpegFiles.count) existing CoreML samples for label '\(label)'")
            return jpegFiles
        } catch {
            print("Error reading CoreML directory for label '\(label)': \(error)")
            return []
        }
    }
    
    // Get all existing labels with their image counts
    func getAllLabelsWithCounts() -> [(label: String, count: Int)] {
        let labels = manager.getExistingLabels()
        return labels.map { label in
            let count = manager.getImageCount(for: label)
            return (label: label, count: count)
        }
    }
}

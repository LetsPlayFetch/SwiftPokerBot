import Foundation
import AppKit

class RapidCollectionManager {
    static let shared = RapidCollectionManager()
    
    private let rapidDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("RapidCollection")
    }()
    
    init() {
        createRapidDirectoryIfNeeded()
    }
    
    private func createRapidDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: rapidDirectory, withIntermediateDirectories: true, attributes: nil)
            print("Rapid collection directory ready: \(rapidDirectory.path)")
        } catch {
            print("Failed to create rapid collection directory: \(error)")
        }
    }
    
    // MARK: - Tagged Save Methods
    
    /// Tagged save: captures images to tagged folder
    func taggedSave(screenshot: NSImage, region: RegionBox, tag: String, enhancedMode: Bool) -> Bool {
        // Create tag-specific directory
        let tagDirectory = rapidDirectory.appendingPathComponent(tag)
        do {
            try FileManager.default.createDirectory(at: tagDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create tag directory \(tag): \(error)")
            return false
        }
        
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let dateString = formatter.string(from: timestamp)
        
        if enhancedMode {
            // Enhanced mode: capture 7 images with offsets
            return captureMultipleImages(screenshot: screenshot, region: region, tag: tag, dateString: dateString, tagDirectory: tagDirectory)
        } else {
            // Regular mode: single image capture
            return captureSingleImage(screenshot: screenshot, region: region, tag: tag, dateString: dateString, tagDirectory: tagDirectory)
        }
    }
    
    /// Capture single image to tagged folder
    private func captureSingleImage(screenshot: NSImage, region: RegionBox, tag: String, dateString: String, tagDirectory: URL) -> Bool {
        let uuid = UUID().uuidString.prefix(8)
        let filename = "\(region.name)_\(dateString)_\(uuid).jpg"
        let fileURL = tagDirectory.appendingPathComponent(filename)
        
        print("Rapid saving to: \(tag)/\(fileURL.lastPathComponent)")
        
        guard let croppedImage = ImageUtilities.croppedImage(in: screenshot, for: region) else {
            print("Failed to crop image for rapid collection")
            return false
        }
        
        let success = ImageUtilities.saveAsJPEG(croppedImage, to: fileURL, quality: 0.85)
        
        if success {
            print("Rapid save successful")
        } else {
            print("Rapid save failed")
        }
        
        return success
    }
    
    /// Capture 7 images with offsets to tagged folder
    private func captureMultipleImages(screenshot: NSImage, region: RegionBox, tag: String, dateString: String, tagDirectory: URL) -> Bool {
        // Generate 7 unique positions (1 original + 6 offsets)
        let positions = generateUniquePositions(originalRegion: region)
        
        print("Enhanced saving 7 images for region: \(region.name) to tag: \(tag)")
        
        var successCount = 0
        
        for (index, offsetRegion) in positions.enumerated() {
            let sequentialNumber = String(format: "%03d", index + 1)
            let filename = "\(region.name)_\(dateString)_\(sequentialNumber).jpg"
            let fileURL = tagDirectory.appendingPathComponent(filename)
            
            // Crop the offset region from the screenshot
            guard let croppedImage = ImageUtilities.croppedImage(in: screenshot, for: offsetRegion) else {
                print("Failed to crop region \(sequentialNumber)")
                continue
            }
            
            // Save the cropped image
            let success = ImageUtilities.saveAsJPEG(croppedImage, to: fileURL, quality: 0.85)
            
            if success {
                successCount += 1
                print("Saved \(sequentialNumber): \(tag)/\(filename)")
            } else {
                print("Failed to save \(sequentialNumber): \(tag)/\(filename)")
            }
        }
        
        print("Enhanced save complete: \(successCount)/7 images saved to tag: \(tag)")
        return successCount > 0
    }
    
    /// Generate 7 unique positions: 1 original + 6 random offsets (±5 pixels)
    private func generateUniquePositions(originalRegion: RegionBox) -> [RegionBox] {
        var positions: [RegionBox] = []
        var usedOffsets: Set<String> = []
        
        // Always include the original position first
        positions.append(originalRegion)
        usedOffsets.insert("0,0") // Original position offset
        
        // Generate 6 unique random offsets
        while positions.count < 7 {
            let xOffset = Int.random(in: -5...5)
            let yOffset = Int.random(in: -5...5)
            let offsetKey = "\(xOffset),\(yOffset)"
            
            // Check if this offset is already used
            if !usedOffsets.contains(offsetKey) {
                usedOffsets.insert(offsetKey)
                
                // Create new region with offset
                let offsetRect = CGRect(
                    x: originalRegion.rect.origin.x + CGFloat(xOffset),
                    y: originalRegion.rect.origin.y + CGFloat(yOffset),
                    width: originalRegion.rect.size.width,
                    height: originalRegion.rect.size.height
                )
                
                let offsetRegion = RegionBox(
                    id: UUID(),
                    name: originalRegion.name,
                    rect: offsetRect
                )
                
                positions.append(offsetRegion)
            }
        }
        
        return positions
    }
    
    // MARK: - Utility Methods
    
    /// Get all collected images across all tags
    func getCollectedImages() -> [URL] {
        do {
            let tagDirectories = try FileManager.default.contentsOfDirectory(at: rapidDirectory, includingPropertiesForKeys: [.isDirectoryKey])
            var allImages: [URL] = []
            
            for tagDir in tagDirectories {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: tagDir.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    let images = try FileManager.default.contentsOfDirectory(at: tagDir, includingPropertiesForKeys: nil)
                        .filter { $0.pathExtension.lowercased() == "jpg" }
                    allImages.append(contentsOf: images)
                }
            }
            
            return allImages
        } catch {
            print("Error reading rapid collection directory: \(error)")
            return []
        }
    }
    
    /// Get directory info for UI display
    func getDirectoryInfo() -> (path: String, count: Int) {
        let count = getCollectedImages().count
        return (path: rapidDirectory.path, count: count)
    }
    
    /// Get tagged directory info for UI display
    func getTaggedDirectoryInfo() -> [(tag: String, count: Int)] {
        do {
            let tagDirectories = try FileManager.default.contentsOfDirectory(at: rapidDirectory, includingPropertiesForKeys: [.isDirectoryKey])
            var tagInfo: [(tag: String, count: Int)] = []
            
            for tagDir in tagDirectories {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: tagDir.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    let images = try FileManager.default.contentsOfDirectory(at: tagDir, includingPropertiesForKeys: nil)
                        .filter { $0.pathExtension.lowercased() == "jpg" }
                    tagInfo.append((tag: tagDir.lastPathComponent, count: images.count))
                }
            }
            
            return tagInfo.sorted { $0.tag < $1.tag }
        } catch {
            print("Error reading tag directories: \(error)")
            return []
        }
    }
    
    /// Clear all rapid collection images (for cleanup)
    func clearAllRapidImages() -> Bool {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: rapidDirectory, includingPropertiesForKeys: nil)
            for item in contents {
                try FileManager.default.removeItem(at: item)
            }
            print("Cleared rapid collection directory")
            return true
        } catch {
            print("Failed to clear rapid collection directory: \(error)")
            return false
        }
    }
    
    /// Open the rapid collection folder in Finder
    func openInFinder() {
        NSWorkspace.shared.open(rapidDirectory)
    }
}

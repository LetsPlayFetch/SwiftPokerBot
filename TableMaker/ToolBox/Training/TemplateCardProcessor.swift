import Foundation
import AppKit

struct TemplateInfo {
    let template: ZNCCTemplate
    let imagePath: URL
}

enum TemplateFolder: String, CaseIterable {
    case board = "BoardCardTemplates"
    case player = "PlayerCardTemplates"
    
    var displayName: String {
        switch self {
        case .board: return "Board Cards"
        case .player: return "Player Cards"
        }
    }
}

class TemplateCardProcessor: ObservableObject {
    @Published private(set) var templates: [ZNCCTemplate] = []
    @Published private(set) var templatesByLabel: [String: [TemplateInfo]] = [:]
    @Published var selectedFolder: TemplateFolder = .board
    
    private let baseDirectory: URL
    private let badMatchesDirectory: URL
    private let templateSize = CGSize(width: 35, height: 50)
    
    // Threshold for bad matches (auto-save if score < this)
    private let badMatchThreshold: Float = 0.80
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        baseDirectory = docs.appendingPathComponent("CardTemplates")
        badMatchesDirectory = baseDirectory.appendingPathComponent("BadMatches")
        
        print("📁 Base template directory: \(baseDirectory.path)")
        loadTemplates()
    }
    
    // MARK: - Template Loading/Saving
    
    /// Get current folder URL based on selection
    private func currentTemplateDirectory() -> URL {
        return baseDirectory.appendingPathComponent(selectedFolder.rawValue)
    }
    
    /// Load templates from currently selected folder
    func loadTemplates() {
        let templatesDirectory = currentTemplateDirectory()
        print("🔄 Loading templates from: \(templatesDirectory.lastPathComponent)")
        
        do {
            try FileManager.default.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)
            
            let rankFolders = try FileManager.default.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: [.isDirectoryKey])
                .filter { $0.hasDirectoryPath }
            
            templates = []
            templatesByLabel = [:]
            
            for rankFolder in rankFolders {
                let rankLabel = rankFolder.lastPathComponent
                print("📂 Loading templates for rank: \(rankLabel)")
                
                let templateFolders = try FileManager.default.contentsOfDirectory(at: rankFolder, includingPropertiesForKeys: [.isDirectoryKey])
                    .filter { $0.hasDirectoryPath }
                
                var rankTemplates: [TemplateInfo] = []
                
                for templateFolder in templateFolders {
                    do {
                        let template = try ZNCCIO.loadTemplate(at: templateFolder)
                        let imagePath = templateFolder.appendingPathComponent("processed.jpg")
                        
                        if FileManager.default.fileExists(atPath: imagePath.path) {
                            let templateInfo = TemplateInfo(template: template, imagePath: imagePath)
                            templates.append(template)
                            rankTemplates.append(templateInfo)
                            print("✅ Loaded template: \(template.label) (\(template.id))")
                        } else {
                            print("⚠️ Template image missing for \(template.id), skipping")
                        }
                    } catch {
                        print("⚠️ Failed to load template at \(templateFolder): \(error)")
                    }
                }
                
                if !rankTemplates.isEmpty {
                    templatesByLabel[rankLabel] = rankTemplates
                }
            }
            
            print("📦 Loaded \(templates.count) templates from \(selectedFolder.displayName)")
            
        } catch {
            print("❌ Failed to setup templates directory: \(error)")
        }
    }
    
    /// Create and save template from training image
    func createTemplate(from image: NSImage, label: String) -> Bool {
        print("💾 Creating template for label: \(label) in \(selectedFolder.displayName)")
        
        let id = UUID().uuidString.prefix(8).description
        
        guard let resizedImage = ImageUtilities.resizeImage(image, to: templateSize) else {
            print("❌ Failed to resize image for template creation")
            return false
        }
        
        // Apply aggressive preprocessing
        guard let processedImage = preprocessForTemplate(image: resizedImage) else {
            print("❌ Failed to preprocess image")
            return false
        }
        
        // Create template from processed image
        guard let template = ZNCCTemplateMaker.createTemplate(
            from: processedImage,
            targetSize: templateSize,
            id: id,
            label: label
        ) else {
            print("❌ Failed to create template for \(label)")
            return false
        }
        
        // Save to current folder
        let templatesDirectory = currentTemplateDirectory()
        let rankFolder = templatesDirectory.appendingPathComponent(label)
        
        do {
            try FileManager.default.createDirectory(at: rankFolder, withIntermediateDirectories: true)
            
            let templateFolder = rankFolder.appendingPathComponent(id)
            try ZNCCIO.saveTemplate(template, at: templateFolder)
            
            // Save PROCESSED image (what matcher sees)
            let processedPath = templateFolder.appendingPathComponent("processed.jpg")
            let success = ImageUtilities.saveAsJPEG(processedImage, to: processedPath, quality: 0.95)
            
            if !success {
                print("⚠️ Failed to save processed image")
            }
            
            // Update in-memory collections
            templates.append(template)
            let templateInfo = TemplateInfo(template: template, imagePath: processedPath)
            
            if templatesByLabel[label] == nil {
                templatesByLabel[label] = []
            }
            templatesByLabel[label]?.append(templateInfo)
            
            print("✅ Template saved: \(label) (\(id)) to \(selectedFolder.displayName)")
            return true
            
        } catch {
            print("❌ Failed to save template: \(error)")
            return false
        }
    }
    
    // MARK: - Template Matching
    
    /// Match card using templates
    func getCard(in screenshot: NSImage, for region: RegionBox, completion: @escaping (ZNCCMatch?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            print("🔍 Template matching for region: \(region.name)")
            
            guard let processedImage = self.preprocessForMatching(screenshot: screenshot, region: region) else {
                print("❌ Failed to preprocess image for matching")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Find best template match
            let match = ZNCCMatcher.bestMatch(
                roiNSImage: processedImage,
                templates: self.templates,
                stride: 1,
                refineRadius: 2
            )
            
            if let match = match {
                let scorePercent = match.score * 100
                print("🎯 Match found: \(match.label) (score: \(String(format: "%.1f%%", scorePercent)))")
                
                // Check if this is a bad match
                if match.score < self.badMatchThreshold {
                    print("⚠️ WARNING: Poor template matching (score: \(String(format: "%.2f", match.score)))")
                    self.saveBadMatch(
                        processedImage: processedImage,
                        originalCrop: self.getCroppedOriginal(screenshot: screenshot, region: region),
                        match: match,
                        region: region
                    )
                }
                
                DispatchQueue.main.async { completion(match) }
            } else {
                print("❌ No template match found")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    /// Save bad match for later review
    private func saveBadMatch(processedImage: NSImage, originalCrop: NSImage?, match: ZNCCMatch, region: RegionBox) {
        do {
            try FileManager.default.createDirectory(at: badMatchesDirectory, withIntermediateDirectories: true)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            
            let scoreStr = String(format: "%.2f", match.score)
            let folderName = "\(timestamp)_score\(scoreStr)"
            let badMatchFolder = badMatchesDirectory.appendingPathComponent(folderName)
            
            try FileManager.default.createDirectory(at: badMatchFolder, withIntermediateDirectories: true)
            
            // Save processed image
            let processedPath = badMatchFolder.appendingPathComponent("processed.jpg")
            _ = ImageUtilities.saveAsJPEG(processedImage, to: processedPath, quality: 0.95)
            
            // Save original crop if available
            if let original = originalCrop {
                let originalPath = badMatchFolder.appendingPathComponent("original.jpg")
                _ = ImageUtilities.saveAsJPEG(original, to: originalPath, quality: 0.95)
            }
            
            // Save metadata
            let metadata: [String: Any] = [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "matched_label": match.label,
                "confidence": match.score,
                "threshold": badMatchThreshold,
                "region": region.name,
                "template_id": match.templateId,
                "folder": selectedFolder.rawValue
            ]
            
            let metadataPath = badMatchFolder.appendingPathComponent("metadata.json")
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            try jsonData.write(to: metadataPath)
            
            print("💾 Saved for later review: BadMatches/\(folderName)/")
            
        } catch {
            print("❌ Failed to save bad match: \(error)")
        }
    }
    
    /// Get original cropped image (no preprocessing)
    private func getCroppedOriginal(screenshot: NSImage, region: RegionBox) -> NSImage? {
        guard let cropCI = ImageUtilities.cropROI(screenshot, rect: region.rect) else { return nil }
        let croppedNS = ImageUtilities.ciToNSImage(cropCI)
        return ImageUtilities.resizeImage(croppedNS, to: templateSize)
    }
    
    /// Preprocess for template creation (from already resized image)
    private func preprocessForTemplate(image: NSImage) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return nil }
        
        let processedCI = ciImage
            .applyingFilter("CIPhotoEffectMono")
            .applyingFilter("CIColorControls", parameters: [
                "inputContrast": 3.0,
                "inputBrightness": -0.2
            ])
            .applyingFilter("CIColorThreshold", parameters: [
                "inputThreshold": 0.4
            ])
        
        return ImageUtilities.ciToNSImage(processedCI)
    }
    
    /// Preprocess for matching (crop + resize + filter)
    private func preprocessForMatching(screenshot: NSImage, region: RegionBox) -> NSImage? {
        guard let cropCI = ImageUtilities.cropROI(screenshot, rect: region.rect) else { return nil }
        let croppedNS = ImageUtilities.ciToNSImage(cropCI)
        guard let resizedImage = ImageUtilities.resizeImage(croppedNS, to: templateSize) else { return nil }
        
        return preprocessForTemplate(image: resizedImage)
    }
    
    // MARK: - Template Management
    
    func getTemplateCount(for label: String) -> Int {
        return templatesByLabel[label]?.count ?? 0
    }
    
    func getAllLabels() -> [String] {
        return Array(templatesByLabel.keys).sorted()
    }
    
    func getTemplatesInfo(for label: String) -> [TemplateInfo] {
        return templatesByLabel[label] ?? []
    }
    
    func deleteTemplate(_ templateInfo: TemplateInfo) -> Bool {
        print("🗑️ Deleting template: \(templateInfo.template.label) (\(templateInfo.template.id))")
        
        let templateFolder = templateInfo.imagePath.deletingLastPathComponent()
        do {
            try FileManager.default.removeItem(at: templateFolder)
            
            templates.removeAll { $0.id == templateInfo.template.id }
            
            let label = templateInfo.template.label
            templatesByLabel[label]?.removeAll { $0.template.id == templateInfo.template.id }
            
            if templatesByLabel[label]?.isEmpty == true {
                templatesByLabel.removeValue(forKey: label)
            }
            
            print("✅ Deleted template: \(templateInfo.template.label)")
            return true
        } catch {
            print("❌ Failed to delete template: \(error)")
            return false
        }
    }
    
    func deleteTemplates(for label: String) -> Bool {
        print("🗑️ Deleting all templates for label: \(label)")
        
        let templatesDirectory = currentTemplateDirectory()
        let rankFolder = templatesDirectory.appendingPathComponent(label)
        
        do {
            try FileManager.default.removeItem(at: rankFolder)
            
            templates.removeAll { $0.label == label }
            templatesByLabel.removeValue(forKey: label)
            
            print("✅ Deleted all templates for \(label)")
            return true
        } catch {
            print("❌ Failed to delete templates for \(label): \(error)")
            return false
        }
    }
    
    func clearAllTemplates() -> Bool {
        print("🗑️ Clearing all templates from \(selectedFolder.displayName)")
        
        let templatesDirectory = currentTemplateDirectory()
        do {
            try FileManager.default.removeItem(at: templatesDirectory)
            templates = []
            templatesByLabel = [:]
            print("✅ Cleared all templates")
            return true
        } catch {
            print("❌ Failed to clear templates: \(error)")
            return false
        }
    }
    
    func getTemplateDirectory() -> URL {
        return currentTemplateDirectory()
    }
    
    func getBadMatchesDirectory() -> URL {
        return badMatchesDirectory
    }
    
    // MARK: - Preview Functions
    
    func getCroppedPreview(screenshot: NSImage, region: RegionBox) -> NSImage? {
        guard let cropCI = ImageUtilities.cropROI(screenshot, rect: region.rect) else { return nil }
        let croppedNS = ImageUtilities.ciToNSImage(cropCI)
        return ImageUtilities.resizeImage(croppedNS, to: templateSize)
    }
    
    func getProcessedPreview(screenshot: NSImage, region: RegionBox) -> NSImage? {
        return preprocessForMatching(screenshot: screenshot, region: region)
    }
}

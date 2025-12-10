import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Save/Load TableMap with OCR configs and RGB targets
enum TableMapIO {
    
    // Track the current file URL for "Save" functionality
    private static var currentFileURL: URL?
    
    // MARK: - Save Functions
    
    /// Save complete TableMap (regions + OCR configs + RGB targets)
    static func saveMap(
        regions: [RegionBox],
        ocrConfigs: OCRConfigs,
        rgbTargets: RGBTargets
    ) -> Bool {
        if let url = currentFileURL {
            return saveToURL(regions: regions, ocrConfigs: ocrConfigs, rgbTargets: rgbTargets, url: url)
        } else {
            return saveAsMap(regions: regions, ocrConfigs: ocrConfigs, rgbTargets: rgbTargets)
        }
    }
    
    /// Save As (always prompts for location)
    static func saveAsMap(
        regions: [RegionBox],
        ocrConfigs: OCRConfigs,
        rgbTargets: RGBTargets
    ) -> Bool {
        guard let url = chooseSaveURL() else { return false }
        let success = saveToURL(regions: regions, ocrConfigs: ocrConfigs, rgbTargets: rgbTargets, url: url)
        if success {
            currentFileURL = url
        }
        return success
    }
    
    /// Save to specific URL
    private static func saveToURL(
        regions: [RegionBox],
        ocrConfigs: OCRConfigs,
        rgbTargets: RGBTargets,
        url: URL
    ) -> Bool {
        let tableMap = TableMap(
            regions: regions,
            ocrConfigs: ocrConfigs,
            rgbTargets: rgbTargets
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(tableMap)
            try data.write(to: url)
            print("✅ Saved TableMap → \(url.path)")
            return true
        } catch {
            print("⚠️ Save failed:", error)
            return false
        }
    }
    
    // MARK: - Load Functions
    
    /// Load TableMap with backward compatibility
    /// Returns: (regions, ocrConfigs, rgbTargets) or nil if load fails
    static func loadMap() -> (regions: [RegionBox], ocrConfigs: OCRConfigs, rgbTargets: RGBTargets)? {
        guard let url = chooseOpenURL() else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            // Try new format first (TableMap)
            if let tableMap = try? decoder.decode(TableMap.self, from: data) {
                print("✅ Loaded TableMap (new format) ← \(url.path)")
                currentFileURL = url
                return (tableMap.regions, tableMap.ocrConfigs, tableMap.rgbTargets)
            }
            
            // Fallback: Try old format ([RegionBox] only)
            if let regions = try? decoder.decode([RegionBox].self, from: data) {
                print("⚠️ Loaded old format map - using default OCR/RGB configs")
                print("   File: \(url.path)")
                currentFileURL = url
                
                // Generate default configs
                let defaultOCRConfigs = generateDefaultOCRConfigs()
                let defaultRGBTargets = RGBTargets.default
                
                return (regions, defaultOCRConfigs, defaultRGBTargets)
            }
            
            print("❌ Failed to decode map file")
            return nil
            
        } catch {
            print("❌ Load failed:", error)
            return nil
        }
    }
    
    // MARK: - Helper Functions
    
    /// Generate default OCR configs from current defaults
    private static func generateDefaultOCRConfigs() -> OCRConfigs {
        return OCRConfigs(
            baseOCR: .default,
            playerBet: OCRParameters(
                scale: 6.0,
                sharpness: 0.4,
                contrast: 1.5,
                brightness: 0.0,
                saturation: 0.0,
                blurRadius: 2.0,
                threshold: 0.55,
                morphRadius: 0.5,
                colorFilterMode: .hsvFilter,
                hsvHueMin: 60.0,
                hsvHueMax: 180.0,
                hsvSatMin: 0.30,
                hsvSatMax: 1.0
            ),
            playerBalance: OCRParameters(
                scale: 4.0,
                sharpness: 0.40,
                contrast: 1.60,
                brightness: 0.30,
                saturation: 0.0,
                blurRadius: 0.50,
                threshold: 0.20,
                morphRadius: 0.10,
                colorFilterMode: .colorDistance,
                colorDistanceThreshold: 0.40
            ),
            playerAction: OCRParameters(
                scale: 4.0,
                sharpness: 0.40,
                contrast: 1.40,
                brightness: 0.40,
                saturation: 0.0,
                blurRadius: 0.50,
                threshold: 0.50,
                morphRadius: 0.10,
                colorFilterMode: .colorDistance,
                colorDistanceThreshold: 0.40
            ),
            tablePot: OCRParameters(
                scale: 4.0,
                sharpness: 0.40,
                contrast: 1.60,
                brightness: 0.30,
                saturation: 0.0,
                blurRadius: 0.50,
                threshold: 0.25,
                morphRadius: 0.10,
                colorFilterMode: .colorDistance,
                colorDistanceThreshold: 0.80
            )
        )
    }
    
    /// Prompt user for save location
    private static func chooseSaveURL(defaultName: String = "Untitled.tablemap") -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
    
    /// Prompt user for file to open
    private static func chooseOpenURL() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
    
    // MARK: - File Management
    
    /// Get the current file name (for UI display)
    static func getCurrentFileName() -> String {
        return currentFileURL?.lastPathComponent ?? "Untitled"
    }
    
    /// Check if there's a current file
    static func hasCurrentFile() -> Bool {
        return currentFileURL != nil
    }
    
    /// Create a new file (clears current file URL)
    static func newMap() {
        currentFileURL = nil
    }
}

import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Stand-alone helper for saving & loading `[RegionBox]` as JSON.
enum TableMapIO {
    
    // Track the current file URL for "Save" functionality
    private static var currentFileURL: URL?
    
    /// Prompts user with `NSSavePanel`, returns URL on success.
    private static func chooseSaveURL(defaultName: String = "Untitled.tablemap") -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
    
    /// Prompts user with `NSOpenPanel`, returns URL on success.
    private static func chooseOpenURL() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
    
    /// Save regions to a specific URL
    private static func saveToURL(_ regions: [RegionBox], url: URL) -> Bool {
        do {
            let data = try JSONEncoder().encode(regions)
            try data.write(to: url)
            print("Saved map → \(url.path)")
            return true
        } catch {
            print("⚠️ Save failed:", error)
            return false
        }
    }
    
    /// Save regions → current file (if exists), otherwise prompt for location
    static func saveMap(_ regions: [RegionBox]) -> Bool {
        if let url = currentFileURL {
            return saveToURL(regions, url: url)
        } else {
            return saveAsMap(regions)
        }
    }
    
    /// Save regions → user-selected file (always prompts)
    static func saveAsMap(_ regions: [RegionBox]) -> Bool {
        guard let url = chooseSaveURL() else { return false }
        let success = saveToURL(regions, url: url)
        if success {
            currentFileURL = url
        }
        return success
    }
    
    /// Load regions ← user-selected file; returns nil on cancel/failure.
    static func loadMap() -> [RegionBox]? {
        guard let url = chooseOpenURL() else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let regions = try JSONDecoder().decode([RegionBox].self, from: data)
            print("Loaded map ← \(url.path)")
            // Set the current file URL for "Save" path
            currentFileURL = url
            return regions
        } catch {
            print("⚠️ Load failed:", error)
            return nil
        }
    }
    
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

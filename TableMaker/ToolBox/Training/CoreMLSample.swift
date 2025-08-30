import Foundation
import AppKit

struct CoreMLSample {
    let id: UUID
    let rawImage: NSImage  // Raw cropped image, not processed
    let label: String
    let regionName: String
    let timestamp: Date
    
    init(rawImage: NSImage, label: String, regionName: String) {
        self.id = UUID()
        self.rawImage = rawImage
        self.label = label
        self.regionName = regionName
        self.timestamp = Date()
    }
    
    // Generate filename for the CoreML training image
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: timestamp)
        
        // Clean the label for filename use
        let cleanLabel = label.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        
        return "\(cleanLabel)_\(dateString)_\(id.uuidString.prefix(8)).jpg"
    }
}

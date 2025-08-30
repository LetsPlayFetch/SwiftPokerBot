import Foundation
import AppKit

struct Trainingsample {
    let id: UUID
    let ocrType: OCRType
    let processedImage: NSImage
    let correctLabel: String
    let regionName: String
    let timestamp: Date
    
    init(ocrType: OCRType, processedImage: NSImage, correctLabel: String, regionName: String) {
        self.id = UUID()
        self.ocrType = ocrType
        self.processedImage = processedImage
        self.correctLabel = correctLabel
        self.regionName = regionName
        self.timestamp = Date()
    }
    
    // Generate filename for the training image
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: timestamp)
        
        // Clean the label for filename use
        let cleanLabel = correctLabel.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        
        return "\(regionName)_\(cleanLabel)_\(dateString)_\(id.uuidString.prefix(8)).tiff"
    }
    
    // Generate ground truth filename (for Tesseract training)
    func generateGroundTruthFilename() -> String {
        let imageFilename = generateFilename()
        return imageFilename.replacingOccurrences(of: ".tiff", with: ".gt.txt")
    }
}

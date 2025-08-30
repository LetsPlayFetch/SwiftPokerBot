import Foundation

struct TrainingDataManager {
    static let shared = TrainingDataManager()
    
    private let baseDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("TesseractTraining")
    }()
    
    // Subdirectories for different OCR types
    private let ocrTypeDirectories: [OCRType: String] = [
        .cardRank: "CardRanks",
        .playerBet: "PlayerBets",
        .playerBalance: "PlayerBalances",
        .playerAction: "PlayerActions",
        .tablePot: "TablePots",
        .baseOCR: "BaseOCR"
    ]
    
    init() {
        do {
            try createDirectoriesIfNeeded()
        } catch {
            print("Critical error: Failed to create training directories: \(error)")
        }
    }
    
    private func createDirectoriesIfNeeded() throws {
        print("Creating training directories at: \(baseDirectory.path)")
        
        // Create base directory
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
        print("Base directory created: \(baseDirectory.path)")
        
        // Create subdirectories for each OCR type
        for (ocrType, subdirName) in ocrTypeDirectories {
            let subdirURL = baseDirectory.appendingPathComponent(subdirName)
            try FileManager.default.createDirectory(at: subdirURL, withIntermediateDirectories: true, attributes: nil)
            print("Created subdirectory for \(ocrType): \(subdirURL.path)")
        }
    }
    
    func getDirectoryURL(for ocrType: OCRType) -> URL {
        let subdirName = ocrTypeDirectories[ocrType] ?? "Unknown"
        return baseDirectory.appendingPathComponent(subdirName)
    }
    
    // Add method to check if directories exist and are writable
    func validateDirectories() -> (success: Bool, message: String) {
        // Check base directory
        guard FileManager.default.fileExists(atPath: baseDirectory.path) else {
            return (false, "Base directory does not exist: \(baseDirectory.path)")
        }
        
        // Check if base directory is writable
        guard FileManager.default.isWritableFile(atPath: baseDirectory.path) else {
            return (false, "Base directory is not writable: \(baseDirectory.path)")
        }
        
        // Check all subdirectories
        for (ocrType, subdirName) in ocrTypeDirectories {
            let subdirURL = baseDirectory.appendingPathComponent(subdirName)
            
            guard FileManager.default.fileExists(atPath: subdirURL.path) else {
                return (false, "Subdirectory does not exist: \(subdirURL.path)")
            }
            
            guard FileManager.default.isWritableFile(atPath: subdirURL.path) else {
                return (false, "Subdirectory is not writable: \(subdirURL.path)")
            }
        }
        
        return (true, "All directories exist and are writable")
    }
}

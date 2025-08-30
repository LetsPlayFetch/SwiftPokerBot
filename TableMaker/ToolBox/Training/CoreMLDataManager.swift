import Foundation

struct CoreMLDataManager {
    static let shared = CoreMLDataManager()
    
    private let baseDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("CoreMLData")
    }()
    
    init() {
        do {
            try createBaseDirectoryIfNeeded()
        } catch {
            print("Critical error: Failed to create CoreML base directory: \(error)")
        }
    }
    
    private func createBaseDirectoryIfNeeded() throws {
        print("Creating CoreML base directory at: \(baseDirectory.path)")
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
        print("CoreML base directory created: \(baseDirectory.path)")
    }
    
    func getDirectoryURL(for label: String) -> URL {
        // Clean the label for folder naming
        let cleanLabel = label.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        
        return baseDirectory.appendingPathComponent(cleanLabel)
    }
    
    func createLabelDirectoryIfNeeded(for label: String) throws {
        let labelDirectory = getDirectoryURL(for: label)
        
        if !FileManager.default.fileExists(atPath: labelDirectory.path) {
            try FileManager.default.createDirectory(at: labelDirectory, withIntermediateDirectories: true, attributes: nil)
            print("Created CoreML label directory: \(labelDirectory.path)")
        }
    }
    
    // Get all existing label folders
    func getExistingLabels() -> [String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: [.isDirectoryKey])
            
            let labelFolders = contents.compactMap { url -> String? in
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else { return nil }
                
                return url.lastPathComponent.replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: "/")
            }
            
            return labelFolders.sorted()
        } catch {
            print("Error reading CoreML directories: \(error)")
            return []
        }
    }
    
    // Check if directories exist and are writable
    func validateDirectories() -> (success: Bool, message: String) {
        // Check base directory
        guard FileManager.default.fileExists(atPath: baseDirectory.path) else {
            return (false, "CoreML base directory does not exist: \(baseDirectory.path)")
        }
        
        // Check if base directory is writable
        guard FileManager.default.isWritableFile(atPath: baseDirectory.path) else {
            return (false, "CoreML base directory is not writable: \(baseDirectory.path)")
        }
        
        return (true, "CoreML directory exists and is writable")
    }
    
    // Get count of images in a specific label folder
    func getImageCount(for label: String) -> Int {
        let labelDirectory = getDirectoryURL(for: label)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: labelDirectory, includingPropertiesForKeys: nil)
            let jpegFiles = files.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" }
            return jpegFiles.count
        } catch {
            return 0
        }
    }
}

import Foundation
import Vision
import CoreImage
import AppKit

/// Main OCR service that coordinates different OCR processors (Thread-safe implementation)
struct OCRService {
    private let cardRankOCR = CardRankOCR()
    private let playerBetOCR = PlayerBetOCR()
    private let playerBalanceOCR = PlayerBalanceOCR()
    private let playerActionOCR = PlayerActionOCR()
    private let tablePotOCR = TablePotOCR()
    
    // Thread-safe base processor with synchronized access
    private var baseOCRProcessor: ThreadSafeBaseOCRProcessor
    
    // Operation management for cancellation and throttling
    private static let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3 // Limit concurrent OCR operations
        queue.qualityOfService = .userInitiated
        queue.name = "OCRService.operationQueue"
        return queue
    }()
    
    // Track active operations for cancellation
    private static var activeOperations: [String: Operation] = [:]
    private static let operationsLock = NSLock()
    
    // Debouncing for rapid calls
    private static var debounceTimers: [String: Timer] = [:]
    private static let timersLock = NSLock()
    
    init(baseOCRParameters: OCRParameters = .default) {
        self.baseOCRProcessor = ThreadSafeBaseOCRProcessor(parameters: baseOCRParameters)
    }
    
    // MARK: - Parameter Management (Thread-safe)
    
    /// Update base OCR parameters (Thread-safe)
    mutating func updateBaseOCRParameters(_ parameters: OCRParameters) {
        baseOCRProcessor.updateParameters(parameters)
    }
    
    /// Get current base OCR parameters (Thread-safe)
    func getBaseOCRParameters() -> OCRParameters {
        return baseOCRProcessor.getParameters()
    }
    
    // MARK: - Operation Management
    
    private static func cancelExistingOperation(for key: String) {
        operationsLock.lock()
        defer { operationsLock.unlock() }
        
        if let existingOp = activeOperations[key] {
            existingOp.cancel()
            activeOperations.removeValue(forKey: key)
        }
    }
    
    private static func addOperation(_ operation: Operation, for key: String) {
        operationsLock.lock()
        defer { operationsLock.unlock() }
        activeOperations[key] = operation
    }
    
    private static func removeOperation(for key: String) {
        operationsLock.lock()
        defer { operationsLock.unlock() }
        activeOperations.removeValue(forKey: key)
    }
    
    private static func debounceOperation(key: String, delay: TimeInterval = 0.1, operation: @escaping () -> Void) {
        timersLock.lock()
        defer { timersLock.unlock() }
        
        // Cancel existing timer for this key
        debounceTimers[key]?.invalidate()
        
        // Create new timer
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            timersLock.lock()
            debounceTimers.removeValue(forKey: key)
            timersLock.unlock()
            operation()
        }
        
        debounceTimers[key] = timer
    }
    
    // MARK: - Main Entry Points (Thread-safe with debouncing)
    
    /// Generic text reading with configurable preprocessing (Thread-safe)
    func readValue(in screenshot: NSImage,
                   for region: RegionBox,
                   completion: @escaping (String?) -> Void) {
        let operationKey = "readValue_\(region.id.uuidString)"
        
        // Debounce rapid calls for the same region
        Self.debounceOperation(key: operationKey) {
            self.performReadValue(screenshot: screenshot, region: region, operationKey: operationKey, completion: completion)
        }
    }
    
    private func performReadValue(screenshot: NSImage, region: RegionBox, operationKey: String, completion: @escaping (String?) -> Void) {
        Self.cancelExistingOperation(for: operationKey)
        
        let operation = BlockOperation { [baseOCRProcessor] in
            // Check cancellation before starting work
            guard !Thread.current.isCancelled else { return }
            
            // Perform OCR processing
            baseOCRProcessor.processGeneric(screenshot: screenshot, region: region) { result in
                // Always return to main queue
                DispatchQueue.main.async {
                    // Final cancellation check before calling completion
                    guard !Thread.current.isCancelled else { return }
                    Self.removeOperation(for: operationKey)
                    completion(result)
                }
            }
        }
        
        Self.addOperation(operation, for: operationKey)
        Self.operationQueue.addOperation(operation)
    }
    
    /// Card rank reading with specialized preprocessing (Thread-safe)
    func readCardRank(in screenshot: NSImage,
                      for region: RegionBox,
                      completion: @escaping (NSImage, String) -> Void) {
        let operationKey = "cardRank_\(region.id.uuidString)"
        
        Self.debounceOperation(key: operationKey) {
            self.performCardRankOCR(screenshot: screenshot, region: region, operationKey: operationKey, completion: completion)
        }
    }
    
    private func performCardRankOCR(screenshot: NSImage, region: RegionBox, operationKey: String, completion: @escaping (NSImage, String) -> Void) {
        Self.cancelExistingOperation(for: operationKey)
        
        let operation = BlockOperation { [cardRankOCR] in
            guard !Thread.current.isCancelled else { return }
            
            cardRankOCR.process(screenshot: screenshot, region: region) { image, text in
                DispatchQueue.main.async {
                    guard !Thread.current.isCancelled else { return }
                    Self.removeOperation(for: operationKey)
                    completion(image, text)
                }
            }
        }
        
        Self.addOperation(operation, for: operationKey)
        Self.operationQueue.addOperation(operation)
    }
    
    /// Player bet reading with specialized preprocessing (Thread-safe)
    func readPlayerBet(in screenshot: NSImage,
                       for region: RegionBox,
                       completion: @escaping (NSImage, String) -> Void) {
        let operationKey = "playerBet_\(region.id.uuidString)"
        
        Self.debounceOperation(key: operationKey) {
            self.performPlayerBetOCR(screenshot: screenshot, region: region, operationKey: operationKey, completion: completion)
        }
    }
    
    private func performPlayerBetOCR(screenshot: NSImage, region: RegionBox, operationKey: String, completion: @escaping (NSImage, String) -> Void) {
        Self.cancelExistingOperation(for: operationKey)
        
        let operation = BlockOperation { [playerBetOCR] in
            guard !Thread.current.isCancelled else { return }
            
            playerBetOCR.process(screenshot: screenshot, region: region) { image, text in
                DispatchQueue.main.async {
                    guard !Thread.current.isCancelled else { return }
                    Self.removeOperation(for: operationKey)
                    completion(image, text)
                }
            }
        }
        
        Self.addOperation(operation, for: operationKey)
        Self.operationQueue.addOperation(operation)
    }
    
    /// Player balance reading with specialized preprocessing (Thread-safe)
    func readPlayerBalance(in screenshot: NSImage,
                          for region: RegionBox,
                          completion: @escaping (NSImage, String) -> Void) {
        let operationKey = "playerBalance_\(region.id.uuidString)"
        
        Self.debounceOperation(key: operationKey) {
            self.performPlayerBalanceOCR(screenshot: screenshot, region: region, operationKey: operationKey, completion: completion)
        }
    }
    
    private func performPlayerBalanceOCR(screenshot: NSImage, region: RegionBox, operationKey: String, completion: @escaping (NSImage, String) -> Void) {
        Self.cancelExistingOperation(for: operationKey)
        
        let operation = BlockOperation { [playerBalanceOCR] in
            guard !Thread.current.isCancelled else { return }
            
            playerBalanceOCR.process(screenshot: screenshot, region: region) { image, text in
                DispatchQueue.main.async {
                    guard !Thread.current.isCancelled else { return }
                    Self.removeOperation(for: operationKey)
                    completion(image, text)
                }
            }
        }
        
        Self.addOperation(operation, for: operationKey)
        Self.operationQueue.addOperation(operation)
    }
    
    /// Player action reading with specialized preprocessing (Thread-safe)
    func readPlayerAction(in screenshot: NSImage,
                         for region: RegionBox,
                         completion: @escaping (NSImage, String) -> Void) {
        let operationKey = "playerAction_\(region.id.uuidString)"
        
        Self.debounceOperation(key: operationKey) {
            self.performPlayerActionOCR(screenshot: screenshot, region: region, operationKey: operationKey, completion: completion)
        }
    }
    
    private func performPlayerActionOCR(screenshot: NSImage, region: RegionBox, operationKey: String, completion: @escaping (NSImage, String) -> Void) {
        Self.cancelExistingOperation(for: operationKey)
        
        let operation = BlockOperation { [playerActionOCR] in
            guard !Thread.current.isCancelled else { return }
            
            playerActionOCR.process(screenshot: screenshot, region: region) { image, text in
                DispatchQueue.main.async {
                    guard !Thread.current.isCancelled else { return }
                    Self.removeOperation(for: operationKey)
                    completion(image, text)
                }
            }
        }
        
        Self.addOperation(operation, for: operationKey)
        Self.operationQueue.addOperation(operation)
    }
    
    /// Table pot reading with specialized preprocessing (Thread-safe)
    func readTablePot(in screenshot: NSImage,
                      for region: RegionBox,
                      completion: @escaping (NSImage, String) -> Void) {
        let operationKey = "tablePot_\(region.id.uuidString)"
        
        Self.debounceOperation(key: operationKey) {
            self.performTablePotOCR(screenshot: screenshot, region: region, operationKey: operationKey, completion: completion)
        }
    }
    
    private func performTablePotOCR(screenshot: NSImage, region: RegionBox, operationKey: String, completion: @escaping (NSImage, String) -> Void) {
        Self.cancelExistingOperation(for: operationKey)
        
        let operation = BlockOperation { [tablePotOCR] in
            guard !Thread.current.isCancelled else { return }
            
            tablePotOCR.process(screenshot: screenshot, region: region) { image, text in
                DispatchQueue.main.async {
                    guard !Thread.current.isCancelled else { return }
                    Self.removeOperation(for: operationKey)
                    completion(image, text)
                }
            }
        }
        
        Self.addOperation(operation, for: operationKey)
        Self.operationQueue.addOperation(operation)
    }
    
    // MARK: - Preview Utilities (Thread-safe)
    
    func croppedImage(in screenshot: NSImage, for region: RegionBox) -> NSImage? {
        // Image utilities are already thread-safe (pure functions)
        return ImageUtilities.croppedImage(in: screenshot, for: region)
    }
    
    func preprocessedImage(in screenshot: NSImage, for region: RegionBox) -> NSImage? {
        // Thread-safe preprocessing
        return baseOCRProcessor.preprocessedPreviewImage(from: screenshot, region: region)
    }
    
    func averageColorString(in screenshot: NSImage, for region: RegionBox) -> String? {
        // Image utilities are already thread-safe (pure functions)
        return ImageUtilities.averageColorString(in: screenshot, for: region)
    }
    
    // MARK: - Async Support (Thread-safe)
    
#if swift(>=5.5)
    func readValue(in screenshot: NSImage, for region: RegionBox) async -> String? {
        await withCheckedContinuation { continuation in
            readValue(in: screenshot, for: region) { value in
                continuation.resume(returning: value)
            }
        }
    }
#endif
}

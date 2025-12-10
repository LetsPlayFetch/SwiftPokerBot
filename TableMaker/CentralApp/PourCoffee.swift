import SwiftUI
import ScreenCaptureKit
//import AVFoundation Go Back to using AV FOundation maybe 

class PourCoffee: ObservableObject {
    @Published var image: NSImage?

    private var currentWindow: SCWindow?

    func start(window: SCWindow) async {
        currentWindow = window
        do {
            try await captureCurrentWindow()
        } catch {
            print("Failed to capture window on start: \(error)")
        }
    }

    @MainActor
    func captureOneFrame() async throws {
        try await captureCurrentWindow()
    }
    
    @MainActor
    private func captureCurrentWindow() async throws {
        guard let window = currentWindow else {
            throw CaptureError.noWindow
        }
        
        // Always create fresh filter and config
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        
        // Get current window dimensions
        let contentRect = filter.contentRect
        let scale = CGFloat(filter.pointPixelScale)
        
        config.width = Int(contentRect.width * scale)
        config.height = Int(contentRect.height * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 10)
        config.queueDepth = 3
        config.showsCursor = false //Disable seeing mouse to prevent errors
        config.colorSpaceName = CGColorSpace.sRGB //COnvert to SRGB for standardization and saving overhead
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = false
        
        print("Capturing at current size: \(config.width) x \(config.height)")
        print("Content rect: \(contentRect), Scale: \(scale)")

        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        self.image = NSImage(cgImage: cgImage, size: .zero)
        
        print("Actual captured: \(cgImage.width) x \(cgImage.height)")
    }

    /// Switch to a different window
    @MainActor
    func switchToWindow(_ window: SCWindow) async {
        currentWindow = window
        do {
            try await captureCurrentWindow()
        } catch {
            print("Failed to capture new window: \(error)")
        }
    }
}

enum CaptureError: Error {
    case noWindow
}

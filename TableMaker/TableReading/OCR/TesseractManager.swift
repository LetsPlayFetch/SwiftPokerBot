import Foundation
import CoreGraphics
import ImageIO

class TesseractManager {
    private var handle: UnsafeMutableRawPointer?
    
    init(language: String = "eng") {
        print("Initializing TesseractManager...")
        
        // Set environment variable for Tesseract
        setenv("TESSDATA_PREFIX", "/opt/homebrew/share/tessdata/", 1)
        
        // Use the symlink path with trailing slash
        handle = tesseract_create("/opt/homebrew/share/tessdata/", language)
        
        if handle == nil {
            print("Tesseract initialization failed!")
        } else {
            print("Tesseract initialization succeeded!")
        }
    }
    
    deinit {
        if let h = handle {
            tesseract_destroy(h)
        }
    }
    
    // MARK: - Player Bet Recognition
    
    /// Get player bet amounts - configured for numbers, B, k, periods, commas
    func getPlayerBet(from cgImage: CGImage) -> OCRResult {
        guard let h = handle else {
            print("TesseractManager not initialized!")
            return OCRResult(text: nil, confidence: 0.0)
        }
        
        
        // Set whitelist for player bets: numbers, B, k, period, comma
        tesseract_set_whitelist(h, "0123456789B.,")
        // Set DPI variable to 300 for better recognition
        //tesseract_set_variable(h, "user_defined_dpi", "300")
        
        // Set PSM for single line text (good for bet amounts)
        tesseract_set_page_seg_mode(h, 7) // PSM 7 = single line
        
        return recognizeText(from: cgImage)
    }
    
    func getPlayerBet(fromImagePath path: String) -> OCRResult {
        guard let image = CGImage.create(fromImagePath: path) else {
            return OCRResult(text: nil, confidence: 0.0)
        }
        return getPlayerBet(from: image)
    }
    
    // MARK: - Core OCR Function (Private)
    
    /// Main OCR function with confidence
    private func recognizeText(from cgImage: CGImage) -> OCRResult {
        guard let h = handle else {
            return OCRResult(text: nil, confidence: 0.0)
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        // Create image data buffer
        let imageData = UnsafeMutablePointer<UInt8>.allocate(capacity: height * bytesPerRow)
        defer { imageData.deallocate() }
        
        // Draw image into buffer
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: imageData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return OCRResult(text: nil, confidence: 0.0)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Set image in Tesseract
        let success = tesseract_set_image_data(h, imageData,
                                             Int32(width),
                                             Int32(height),
                                             Int32(bytesPerPixel),
                                             Int32(bytesPerRow))
        guard success != 0 else {
            return OCRResult(text: nil, confidence: 0.0)
        }
        
        // Get text and confidence
        var result = tesseract_get_text_with_confidence(h)
        defer { tesseract_free_ocr_result(&result) }
        
        let text = result.text != nil ? String(cString: result.text!) : nil
        let cleanText = text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        return OCRResult(
            text: cleanText?.isEmpty == false ? cleanText : nil,
            confidence: result.confidence
        )
    }
}

// Helper extension
extension CGImage {
    static func create(fromImagePath path: String) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        return image
    }
}

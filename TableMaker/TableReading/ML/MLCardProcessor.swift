import Foundation
import Vision
import CoreML
import CoreImage
import AppKit

class MLCardProcessor {
    private var model: VNCoreMLModel?
    
    init() {
        loadModel()
    }
    
    private func loadModel() {
        print("🔍 Looking for Cards model...")
        
        // First check what model files are in the bundle
        let allMLModels = Bundle.main.urls(forResourcesWithExtension: "mlmodel", subdirectory: nil) ?? []
        let allMLModelc = Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil) ?? []
        print("📂 Found .mlmodel files: \(allMLModels)")
        print("📂 Found .mlmodelc files: \(allMLModelc)")
        
        // Try to find the compiled model first (Xcode auto-compiles .mlmodel to .mlmodelc)
        guard let modelURL = Bundle.main.url(forResource: "ClubWPTCards", withExtension: "mlmodelc") else {
            print("❌ ClubWPTCards.mlmodelc not found in bundle")
            print("📂 Bundle path: \(Bundle.main.bundlePath)")
            return
        }
        
        print("✅ Found compiled model at: \(modelURL)")
        
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            print("✅ MLModel loaded successfully")
            
            model = try VNCoreMLModel(for: mlModel)
            print("✅ VNCoreMLModel created successfully")
        } catch {
            print("❌ Failed to load model: \(error)")
        }
    }
    
    func getCard(in screenshot: NSImage, for region: RegionBox, completion: @escaping (Card?) -> Void) {
        guard let model = model else {
            print("❌ Model not loaded")
            completion(nil)
            return
        }
        
        guard let cropCI = ImageUtilities.cropROI(screenshot, rect: region.rect) else {
            print("❌ Failed to crop region")
            completion(nil)
            return
        }
        
        guard let cgImage = CIContext().createCGImage(cropCI, from: cropCI.extent) else {
            print("❌ Failed to create CGImage")
            completion(nil)
            return
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("❌ Vision request error: \(error)")
                completion(nil)
                return
            }
            
            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first else {
                print("❌ No classification results")
                completion(nil)
                return
            }
            
            print("🎯 ML Result: '\(topResult.identifier)' confidence: \(topResult.confidence)")
            
            let card = Card.parse(topResult.identifier)
            completion(card)
        }
        
        DispatchQueue.global().async {
            do {
                try VNImageRequestHandler(cgImage: cgImage).perform([request])
            } catch {
                print("❌ Handler error: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    var isModelReady: Bool {
        return model != nil
    }
}

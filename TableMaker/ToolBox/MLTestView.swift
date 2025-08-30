import SwiftUI

//Need to add aditional types from main bot; incorproate with headercontrolsview
struct MLTestView: View {
    let selectedRegion: RegionBox?
    let screenshot: NSImage
    
    @State private var mlResult: String = ""
    @State private var isRunning: Bool = false
    
    private let mlProcessor = MLCardProcessor()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Run") {
                    runMLTest()
                }
                .disabled(selectedRegion == nil || isRunning)
                
                Button("Debug Model") {
                    debugModel()
                }
                
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Spacer()
            }
            
            TextField("ML Result", text: $mlResult)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(true)
            
            Text("Model Ready: \(mlProcessor.isModelReady ? "✅" : "❌")")
                .font(.caption)
                .foregroundColor(mlProcessor.isModelReady ? .green : .red)
        }
        .padding(.horizontal)
    }
    
    private func runMLTest() {
        guard let region = selectedRegion else {
            mlResult = "No region selected"
            return
        }
        
        guard mlProcessor.isModelReady else {
            mlResult = "Model not loaded"
            return
        }
        
        isRunning = true
        mlResult = "Running..."
        
        mlProcessor.getCard(in: screenshot, for: region) { card in
            DispatchQueue.main.async {
                isRunning = false
                if let card = card {
                    mlResult = "\(card.rank)\(card.suit)"
                } else {
                    mlResult = "Empty"
                }
            }
        }
    }
    
    private func debugModel() {
        print("🔧 Debug Model Info:")
        print("   Bundle path: \(Bundle.main.bundlePath)")
        print("   Model ready: \(mlProcessor.isModelReady)")
        
        let allFiles = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: nil) ?? []
        let modelFiles = allFiles.filter { $0.pathExtension == "mlmodel" || $0.pathExtension == "mlmodelc" }
        print("   All model files in bundle: \(modelFiles)")
        
        mlResult = "Check console for debug info"
    }
}

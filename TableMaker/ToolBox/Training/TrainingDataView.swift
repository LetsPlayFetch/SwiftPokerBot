import SwiftUI

struct TrainingDataView: View {
    let selectedRegion: RegionBox?
    let screenshot: NSImage
    let selectedOCRType: OCRType
    let ocrService: OCRService
    
    @State private var labelText: String = ""
    @State private var showingSaveDialog = false
    @State private var saveMessage = ""
    @State private var saveSuccess = false
    @State private var existingLabels: [String] = []
    @State private var isDebugging = false
    @State private var debugInfo = ""
    
    private let trainingSaver = TrainingDataSaver()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Data Collection")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Debug toggle
            Toggle("Show Debug Info", isOn: $isDebugging)
                .toggleStyle(.button)
            
            if isDebugging {
                Text("Debug Information:")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                
                ScrollView {
                    Text(debugInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 100)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            
            if let region = selectedRegion {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Region: \(region.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("OCR Type: \(ocrTypeDisplayName(selectedOCRType))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Test directory access
                    Button("Test Directory Access") {
                        testDirectoryAccess()
                    }
                    .buttonStyle(.bordered)
                    
                    // Show existing labels for this OCR type
                    if !existingLabels.isEmpty {
                        Text("Existing labels (\(existingLabels.count)):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(existingLabels.prefix(5), id: \.self) { label in
                                    Text(label)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                        .onTapGesture {
                                            labelText = label
                                        }
                                }
                                if existingLabels.count > 5 {
                                    Text("+\(existingLabels.count - 5) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 30)
                    }
                    
                    // Label input field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Correct Label:")
                            .font(.subheadline)
                        
                        TextField("Enter the correct text", text: $labelText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                saveTrainingData()
                            }
                        
                        if trainingSaver.labelExists(labelText, for: selectedOCRType) && !labelText.isEmpty {
                            Text("⚠️ This label already exists")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Save button
                    Button(action: saveTrainingData) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Training Sample")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(labelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    // Quick action buttons for common labels
                    if selectedOCRType == .cardRank {
                        quickCardRankButtons
                    }
                }
            } else {
                Text("Select a region to collect training data")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            loadExistingLabels()
            updateDebugInfo()
        }
        .onChange(of: selectedOCRType) { _ in
            loadExistingLabels()
        }
        .alert("Training Data", isPresented: $showingSaveDialog) {
            Button("OK") { }
        } message: {
            Text(saveMessage)
        }
    }
    
    private var quickCardRankButtons: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quick select:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(["A", "K", "Q", "J", "10", "9", "8", "7", "6", "5", "4", "3", "2"], id: \.self) { rank in
                    Button(rank) {
                        labelText = rank
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
    }
    
    private func testDirectoryAccess() {
        let manager = TrainingDataManager.shared
        let validation = manager.validateDirectories()
        
        let testResult = validation.success ? "✅ Directory test passed" : "❌ Directory test failed"
        debugInfo = "\(testResult)\n\(validation.message)\n\nBase directory: \(manager.getDirectoryURL(for: .baseOCR).deletingLastPathComponent().path)"
        
        saveMessage = validation.message
        showingSaveDialog = true
    }
    
    private func updateDebugInfo() {
        guard let region = selectedRegion else {
            debugInfo = "No region selected"
            return
        }
        
        var info = "Region Info:\n"
        info += "  Name: \(region.name)\n"
        info += "  Size: \(region.rect.width) x \(region.rect.height)\n"
        info += "  OCR Type: \(selectedOCRType)\n"
        
        // Test getting processed image
        let processedImage = getProcessedImage(for: region)
        info += "  Processed image valid: \(processedImage.isValid)\n"
        info += "  Processed image size: \(processedImage.size)\n"
        
        debugInfo = info
    }
    
    private func ocrTypeDisplayName(_ type: OCRType) -> String {
        switch type {
        case .cardRank: return "Card Rank"
        case .playerBet: return "Player Bet"
        case .playerBalance: return "Player Balance"
        case .playerAction: return "Player Action"
        case .tablePot: return "Table Pot"
        case .baseOCR: return "Base OCR"
        }
    }
    
    private func loadExistingLabels() {
        let samples = trainingSaver.getExistingSamples(for: selectedOCRType)
        // Extract labels from filenames
        existingLabels = samples.compactMap { filename in
            let components = filename.components(separatedBy: "_")
            return components.count >= 2 ? components[1].replacingOccurrences(of: "-", with: "/") : nil
        }
        .uniqued()
        .sorted()
    }
    
    private func saveTrainingData() {
        guard let region = selectedRegion else {
            saveMessage = "No region selected"
            showingSaveDialog = true
            return
        }
        
        let cleanLabel = labelText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLabel.isEmpty else {
            saveMessage = "Label cannot be empty"
            showingSaveDialog = true
            return
        }
        
        // Get the processed image based on OCR type
        let processedImage = getProcessedImage(for: region)
        
        // Validate the processed image
        guard processedImage.isValid else {
            saveMessage = "Failed to generate valid processed image"
            showingSaveDialog = true
            return
        }
        
        // Create training sample
        let sample = Trainingsample(
            ocrType: selectedOCRType,
            processedImage: processedImage,
            correctLabel: cleanLabel,
            regionName: region.name
        )
        
        print("Attempting to save training sample with label: '\(cleanLabel)'")
        
        // Save the sample
        let success = trainingSaver.saveTrainingSample(sample)
        
        saveSuccess = success
        saveMessage = success ?
            "Training sample saved successfully!\nLabel: '\(cleanLabel)'" :
            "Failed to save training sample. Check console for detailed error information."
        showingSaveDialog = true
        
        if success {
            // Clear the label field and reload existing labels
            labelText = ""
            loadExistingLabels()
        }
        
        // Update debug info
        updateDebugInfo()
    }
    
    private func getProcessedImage(for region: RegionBox) -> NSImage {
        // Get the processed image based on the selected OCR type
        switch selectedOCRType {
        case .baseOCR:
            return ocrService.preprocessedImage(in: screenshot, for: region) ?? NSImage()
        case .cardRank:
            return CardRankOCR().preprocessedPreviewImage(from: screenshot, region: region)
        case .playerBet:
            return PlayerBetOCR().preprocessedPreviewImage(from: screenshot, region: region)
        case .playerBalance:
            return PlayerBalanceOCR().preprocessedPreviewImage(from: screenshot, region: region)
        case .playerAction:
            return PlayerActionOCR().preprocessedPreviewImage(from: screenshot, region: region)
        case .tablePot:
            return TablePotOCR().preprocessedPreviewImage(from: screenshot, region: region)
        }
    }
}

// MARK: - Array Extension for Unique Elements
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

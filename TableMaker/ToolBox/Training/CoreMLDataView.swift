import SwiftUI

struct CoreMLDataView: View {
    let selectedRegion: RegionBox?
    let screenshot: NSImage
    
    @State private var labelText: String = ""
    @State private var showingSaveDialog = false
    @State private var saveMessage = ""
    @State private var saveSuccess = false
    @State private var existingLabels: [(label: String, count: Int)] = []
    @State private var isDebugging = false
    @State private var debugInfo = ""
    
    private let coremlSaver = CoreMLDataSaver()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CoreML Data Collection")
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
                    
                    Text("Type: Raw Image Classification")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Test directory access
                    Button("Test CoreML Directory Access") {
                        testDirectoryAccess()
                    }
                    .buttonStyle(.bordered)
                    
                    // Show existing labels with counts
                    if !existingLabels.isEmpty {
                        Text("Existing labels (\(existingLabels.count)):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(existingLabels.prefix(5), id: \.label) { labelInfo in
                                    VStack(spacing: 2) {
                                        Text(labelInfo.label)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("\(labelInfo.count)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(4)
                                    .onTapGesture {
                                        labelText = labelInfo.label
                                    }
                                }
                                if existingLabels.count > 5 {
                                    Text("+\(existingLabels.count - 5) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 40)
                    }
                    
                    // Label input field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Label:")
                            .font(.subheadline)
                        
                        TextField("Enter the label (e.g., A, K, Q, 10)", text: $labelText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                saveCoreMlData()
                            }
                        
                        if let existingLabel = existingLabels.first(where: { $0.label == labelText }), !labelText.isEmpty {
                            Text("ℹ️ This label exists with \(existingLabel.count) images")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Save button
                    Button(action: saveCoreMlData) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save CoreML Sample")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(labelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    // Quick action buttons for card ranks
                    quickCardRankButtons
                }
            } else {
                Text("Select a region to collect CoreML data")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            loadExistingLabels()
            updateDebugInfo()
        }
        .alert("CoreML Data", isPresented: $showingSaveDialog) {
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
        let manager = CoreMLDataManager.shared
        let validation = manager.validateDirectories()
        
        let testResult = validation.success ? "✅ CoreML directory test passed" : "❌ CoreML directory test failed"
        debugInfo = "\(testResult)\n\(validation.message)\n\nBase directory: \(manager.getDirectoryURL(for: "test").deletingLastPathComponent().path)"
        
        saveMessage = validation.message
        showingSaveDialog = true
    }
    
    private func updateDebugInfo() {
        guard let region = selectedRegion else {
            debugInfo = "No region selected"
            return
        }
        
        var info = "CoreML Region Info:\n"
        info += "  Name: \(region.name)\n"
        info += "  Size: \(region.rect.width) x \(region.rect.height)\n"
        info += "  Type: Raw Image Classification\n"
        
        // Test getting raw cropped image
        let rawImage = getRawImage(for: region)
        info += "  Raw image valid: \(rawImage.isValid)\n"
        info += "  Raw image size: \(rawImage.size)\n"
        
        debugInfo = info
    }
    
    private func loadExistingLabels() {
        existingLabels = coremlSaver.getAllLabelsWithCounts()
    }
    
    private func saveCoreMlData() {
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
        
        // Get the raw cropped image (not processed)
        let rawImage = getRawImage(for: region)
        
        // Validate the raw image
        guard rawImage.isValid else {
            saveMessage = "Failed to generate valid raw image"
            showingSaveDialog = true
            return
        }
        
        // Create CoreML sample
        let sample = CoreMLSample(
            rawImage: rawImage,
            label: cleanLabel,
            regionName: region.name
        )
        
        print("Attempting to save CoreML sample with label: '\(cleanLabel)'")
        
        // Save the sample
        let success = coremlSaver.saveCoreMlSample(sample)
        
        saveSuccess = success
        saveMessage = success ?
            "CoreML sample saved successfully!\nLabel: '\(cleanLabel)'" :
            "Failed to save CoreML sample. Check console for detailed error information."
        showingSaveDialog = true
        
        if success {
            // Clear the label field and reload existing labels
            labelText = ""
            loadExistingLabels()
        }
        
        // Update debug info
        updateDebugInfo()
    }
    
    private func getRawImage(for region: RegionBox) -> NSImage {
        // Get the raw cropped image (not processed)
        return ImageUtilities.croppedImage(in: screenshot, for: region) ?? NSImage()
    }
}

import SwiftUI

struct TemplateMatchingView: View {
    @ObservedObject var templateProcessor: TemplateCardProcessor
    let selectedRegion: RegionBox?
    let screenshot: NSImage
    
    @State private var templateLabel: String = ""
    @State private var matchResult: String = ""
    @State private var matchConfidence: Float = 0.0
    @State private var showTemplateLibrary = false
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showTemplateModal = false
    @State private var selectedLabelForModal = ""
    @State private var showClearConfirmation = false  // NEW: Add confirmation state
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Template Matching")
                    .font(.headline)
                Spacer()
                Button(action: {
                    showTemplateLibrary.toggle()
                }) {
                    Image(systemName: showTemplateLibrary ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }
            
            if showTemplateLibrary {
                VStack(alignment: .leading, spacing: 12) {
                    
                    // Folder selector
                    HStack {
                        Text("Folder:")
                            .frame(width: 50, alignment: .leading)
                        
                        Picker("", selection: $templateProcessor.selectedFolder) {
                            ForEach(TemplateFolder.allCases, id: \.self) { folder in
                                Text(folder.displayName).tag(folder)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: 150)
                        .onChange(of: templateProcessor.selectedFolder) { _ in
                            templateProcessor.loadTemplates()
                        }
                        
                        Spacer()
                    }
                    
                    // Controls
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Label:")
                                .frame(width: 50, alignment: .leading)
                            TextField("A, K, Q, J, T, 9...", text: $templateLabel)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: 120)
                        }
                        
                        HStack(spacing: 8) {
                            Button("Read Template") {
                                performTemplateMatch()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(selectedRegion == nil || isProcessing)
                            
                            Button("Save Template") {
                                saveTemplate()
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedRegion == nil || templateLabel.isEmpty || isProcessing)
                            
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    }
                    
                    // Results with FIXED color coding
                    if !matchResult.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Result:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(matchResult)
                                    .font(.subheadline)
                                    .foregroundColor(getConfidenceColor(matchConfidence))
                            }
                            
                            if matchConfidence > 0 {
                                HStack {
                                    Text("Confidence:")
                                        .font(.caption)
                                    Text(String(format: "%.1f%%", matchConfidence * 100))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(getConfidenceColor(matchConfidence))
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    // Preview Images
                    if let region = selectedRegion {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Template Previews (35x50)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 16) {
                                // Original cropped and resized
                                VStack(spacing: 4) {
                                    Text("Original")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if let preview = templateProcessor.getCroppedPreview(screenshot: screenshot, region: region) {
                                        Image(nsImage: preview)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 90)
                                            .border(Color.gray.opacity(0.5), width: 1)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 60, height: 90)
                                            .overlay(Text("No Preview").font(.caption))
                                    }
                                }
                                
                                // Processed (what matcher sees)
                                VStack(spacing: 4) {
                                    Text("Processed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if let processed = templateProcessor.getProcessedPreview(screenshot: screenshot, region: region) {
                                        Image(nsImage: processed)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 90)
                                            .border(Color.gray.opacity(0.5), width: 1)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 60, height: 90)
                                            .overlay(Text("No Preview").font(.caption))
                                    }
                                }
                            }
                        }
                    }
                    
                    // Template Library
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Template Library")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            
                            Button("Open Templates Folder") {
                                NSWorkspace.shared.open(templateProcessor.getTemplateDirectory())
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            
                            Button("Open Bad Matches") {
                                NSWorkspace.shared.open(templateProcessor.getBadMatchesDirectory())
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                        
                        let allLabels = templateProcessor.getAllLabels()
                        if allLabels.isEmpty {
                            Text("No templates saved yet in \(templateProcessor.selectedFolder.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ScrollView {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    ForEach(allLabels, id: \.self) { label in
                                        VStack(spacing: 6) {
                                            Text(label)
                                                .font(.headline)
                                                .fontWeight(.bold)
                                            
                                            Text("\(templateProcessor.getTemplateCount(for: label)) template\(templateProcessor.getTemplateCount(for: label) == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            HStack(spacing: 8) {
                                                Button("View Images") {
                                                    selectedLabelForModal = label
                                                    showTemplateModal = true
                                                }
                                                .buttonStyle(.plain)
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                
                                                Button("Delete All") {
                                                    deleteTemplates(for: label)
                                                }
                                                .buttonStyle(.plain)
                                                .font(.caption)
                                                .foregroundColor(.red)
                                            }
                                        }
                                        .padding(10)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                            
                            // CHANGED: Clear all button now shows confirmation
                            Button("Clear All Templates in This Folder") {
                                showClearConfirmation = true  // Show confirmation instead of clearing immediately
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
        .overlay(
            Group {
                if showTemplateModal && !selectedLabelForModal.isEmpty {
                    TemplateViewerModal(
                        label: selectedLabelForModal,
                        templates: templateProcessor.getTemplatesInfo(for: selectedLabelForModal),
                        onDeleteTemplate: { templateInfo in
                            let success = templateProcessor.deleteTemplate(templateInfo)
                            if success {
                                templateProcessor.objectWillChange.send()
                            }
                        },
                        onClose: {
                            showTemplateModal = false
                            selectedLabelForModal = ""
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .animation(.easeInOut(duration: 0.2), value: showTemplateModal)
                }
            }
        )
        .alert("Template Action", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        // NEW: Add confirmation alert for clearing all templates
        .alert("Clear All Templates", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                clearAllTemplates()
            }
        } message: {
            Text("Are you sure you want to delete ALL templates in \(templateProcessor.selectedFolder.displayName)?\n\nThis will permanently delete all saved templates and cannot be undone.")
        }
    }
    
    // MARK: - Helper Functions
    
    /// Get color based on confidence score (FIXED for 0-1 range)
    private func getConfidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.85 {
            return .green
        } else if confidence > 0.70 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Actions
    
    private func performTemplateMatch() {
        guard let region = selectedRegion else { return }
        
        isProcessing = true
        matchResult = ""
        matchConfidence = 0.0
        
        templateProcessor.getCard(in: screenshot, for: region) { match in
            DispatchQueue.main.async {
                isProcessing = false
                
                if let match = match {
                    matchResult = match.label
                    matchConfidence = match.score
                    let percent = match.score * 100
                    print("🎯 UI result: \(match.label) (confidence: \(String(format: "%.1f%%", percent)))")
                } else {
                    matchResult = "No match"
                    matchConfidence = 0.0
                    print("❌ UI result: No confident match found")
                }
            }
        }
    }
    
    private func saveTemplate() {
        guard let region = selectedRegion else { return }
        guard !templateLabel.isEmpty else { return }
        
        isProcessing = true
        
        guard let croppedImage = templateProcessor.getCroppedPreview(screenshot: screenshot, region: region) else {
            isProcessing = false
            alertMessage = "Failed to crop region for template"
            showAlert = true
            return
        }
        
        let success = templateProcessor.createTemplate(from: croppedImage, label: templateLabel.uppercased())
        
        isProcessing = false
        
        if success {
            alertMessage = "Template '\(templateLabel.uppercased())' saved to \(templateProcessor.selectedFolder.displayName)!"
            templateLabel = ""
        } else {
            alertMessage = "Failed to save template '\(templateLabel.uppercased())'"
        }
        showAlert = true
    }
    
    private func deleteTemplates(for label: String) {
        let success = templateProcessor.deleteTemplates(for: label)
        alertMessage = success ? "Deleted all templates for '\(label)'" : "Failed to delete templates for '\(label)'"
        showAlert = true
    }
    
    private func clearAllTemplates() {
        let success = templateProcessor.clearAllTemplates()
        alertMessage = success ? "All templates cleared from \(templateProcessor.selectedFolder.displayName)" : "Failed to clear templates"
        showAlert = true
    }
}

import SwiftUI

struct TemplateViewerModal: View {
    let label: String
    let templates: [TemplateInfo]
    let onDeleteTemplate: (TemplateInfo) -> Void
    let onClose: () -> Void
    
    @State private var showingDeleteAlert = false
    @State private var templateToDelete: TemplateInfo?
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
            
            // Modal content
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Templates for '\(label)'")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("\(templates.count) template\(templates.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // Template grid
                if templates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No templates found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
                        ], spacing: 20) {
                            ForEach(templates, id: \.template.id) { templateInfo in
                                TemplateItemView(
                                    templateInfo: templateInfo,
                                    onDelete: {
                                        templateToDelete = templateInfo
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .frame(maxHeight: 500)
                }
                
                // Footer with escape hint
                HStack {
                    Spacer()
                    Text("Press Escape or click outside to close")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 20)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
            .frame(maxWidth: 600, maxHeight: 700)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.makeFirstResponder(NSApp.keyWindow?.contentView)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("EscapePressed"))) { _ in
            onClose()
        }
        .alert("Delete Template", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                templateToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    onDeleteTemplate(template)
                    templateToDelete = nil
                }
            }
        } message: {
            if let template = templateToDelete {
                Text("Are you sure you want to delete this template for '\(template.template.label)'? This action cannot be undone.")
            }
        }
    }
}

struct TemplateItemView: View {
    let templateInfo: TemplateInfo
    let onDelete: () -> Void
    
    @State private var templateImage: NSImage?
    @State private var imageLoadError = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Template image (processed version)
            Group {
                if let image = templateImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 80, maxHeight: 120)
                        .background(Color.white)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                } else if imageLoadError {
                    Rectangle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 30, height: 45)
                        .cornerRadius(6)
                        .overlay(
                            VStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text("Error")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 30, height: 45)
                        .cornerRadius(6)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.5)
                        )
                }
            }
            
            // Template info
            VStack(spacing: 2) {
                Text(templateInfo.template.id)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("σ: \(String(format: "%.6f", templateInfo.template.sigma))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Threshold: \(String(format: "%.2f", templateInfo.template.threshold))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Delete button
            Button(action: onDelete) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.caption)
                    Text("Delete")
                        .font(.caption)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            loadTemplateImage()
        }
    }
    
    private func loadTemplateImage() {
        DispatchQueue.global(qos: .userInteractive).async {
            // Try processed.jpg first, fallback to original.jpg for old templates
            var imagePath = templateInfo.imagePath
            if !FileManager.default.fileExists(atPath: imagePath.path) {
                let originalPath = imagePath.deletingLastPathComponent().appendingPathComponent("original.jpg")
                if FileManager.default.fileExists(atPath: originalPath.path) {
                    imagePath = originalPath
                }
            }
            
            if FileManager.default.fileExists(atPath: imagePath.path) {
                if let image = NSImage(contentsOf: imagePath) {
                    DispatchQueue.main.async {
                        self.templateImage = image
                    }
                } else {
                    DispatchQueue.main.async {
                        self.imageLoadError = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.imageLoadError = true
                }
            }
        }
    }
}

// Extension to handle escape key
extension NSWindow {
    override open func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            NotificationCenter.default.post(name: .init("EscapePressed"), object: nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

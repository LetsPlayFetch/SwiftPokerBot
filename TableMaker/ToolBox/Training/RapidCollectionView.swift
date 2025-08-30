import SwiftUI

struct RapidCollectionView: View {
    @Binding var rapidCollectionMode: Bool
    @Binding var enhancedMode: Bool
    @State private var collectedCount = 0
    @State private var taggedInfo: [(tag: String, count: Int)] = []
    @State private var showingClearAlert = false
    @State private var isDebugging = false
    @State private var debugInfo = ""
    
    private let rapidManager = RapidCollectionManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rapid Collection Mode")
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
                .frame(height: 120)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Main rapid collection toggle
                HStack {
                    Text("Mode:")
                        .font(.subheadline)
                    Spacer()
                    Toggle("", isOn: $rapidCollectionMode)
                        .toggleStyle(.switch)
                }
                
                if rapidCollectionMode {
                    VStack(alignment: .leading, spacing: 6) {
                        // Enhanced mode toggle
                        HStack {
                            Text("Enhanced (7-Shot):")
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: $enhancedMode)
                                .toggleStyle(.switch)
                        }
                        .padding(.leading, 8)
                        
                        // Status display
                        if enhancedMode {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ENHANCED: Click region for card tag popup → 7 offset captures")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                                
                                Text("• 1 original + 6 random offsets (±5px)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("ACTIVE: Click region for card tag popup → instant save")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        
                        // Collection info with tag breakdown
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Total: \(collectedCount) images")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Refresh") {
                                    updateCollectedCount()
                                }
                                .buttonStyle(.plain)
                                .font(.caption)
                            }
                            
                            // Tag breakdown
                            if !taggedInfo.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(taggedInfo, id: \.tag) { info in
                                            Text("\(info.tag): \(info.count)")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                .frame(height: 20)
                            }
                        }
                        
                        // Action buttons
                        HStack(spacing: 8) {
                            Button("Open Folder") {
                                rapidManager.openInFinder()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Clear All") {
                                showingClearAlert = true
                            }
                            .buttonStyle(.bordered)
                            .disabled(collectedCount == 0)
                        }
                    }
                    .padding(.leading, 8)
                } else {
                    Text("Toggle on to enable card tag collection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(rapidCollectionMode ? (enhancedMode ? Color.blue.opacity(0.1) : Color.green.opacity(0.1)) : Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            updateCollectedCount()
            updateDebugInfo()
        }
        .onChange(of: rapidCollectionMode) { _ in
            updateDebugInfo()
        }
        .onChange(of: enhancedMode) { _ in
            updateDebugInfo()
        }
        .alert("Clear All Rapid Images", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                let success = rapidManager.clearAllRapidImages()
                if success {
                    updateCollectedCount()
                }
            }
        } message: {
            Text("This will permanently delete all \(collectedCount) collected images in the rapid collection folder.")
        }
    }
    
    private func updateCollectedCount() {
        collectedCount = rapidManager.getCollectedImages().count
        taggedInfo = rapidManager.getTaggedDirectoryInfo()
        updateDebugInfo()
    }
    
    private func updateDebugInfo() {
        let info = rapidManager.getDirectoryInfo()
        var debug = "Rapid Collection Debug:\n"
        debug += "  Mode Active: \(rapidCollectionMode)\n"
        debug += "  Enhanced Mode: \(enhancedMode)\n"
        debug += "  Directory: \(info.path)\n"
        debug += "  Image Count: \(info.count)\n"
        
        if rapidCollectionMode {
            if enhancedMode {
                debug += "  Instructions: Click region → card tag popup → 7 offset captures\n"
                debug += "  Capture Details: 1 original + 6 offsets (±5px each direction)\n"
            } else {
                debug += "  Instructions: Click region → card tag popup → single capture\n"
            }
        } else {
            debug += "  Instructions: Toggle mode on to activate\n"
        }
        
        debugInfo = debug
    }
}

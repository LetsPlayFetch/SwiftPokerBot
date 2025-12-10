import SwiftUI

struct MapControlsView: View {
    @Binding var drawnRegions: [RegionBox]
    @Binding var selectedRegionID: UUID?
    @Binding var ocrService: OCRService
    @Binding var rgbTargets: RGBTargets
    let onLoad: (OCRConfigs, RGBTargets) -> Void
    
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    saveMap()
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .help(TableMapIO.hasCurrentFile() ?
                      "Save to \(TableMapIO.getCurrentFileName())" :
                      "Save (will prompt for location)")
                
                Button(action: {
                    saveAsMap()
                }) {
                    Label("Save As", systemImage: "square.and.arrow.down.on.square")
                }
                .help("Save with a new name or location")
            }
            
            HStack {
                Button(action: {
                    loadMap()
                }) {
                    Label("Load Map", systemImage: "arrow.down.doc")
                }
                
                Button(action: {
                    newMap()
                }) {
                    Label("New", systemImage: "doc")
                }
                .help("Create a new map (clears current regions)")
            }
        }
        .buttonStyle(.bordered)
        .alert("Save Status", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text(saveAlertMessage)
        }
    }
    
    // MARK: - Save Functions
    
    private func saveMap() {
        let ocrConfigs = getCurrentOCRConfigs()
        let success = TableMapIO.saveMap(
            regions: drawnRegions,
            ocrConfigs: ocrConfigs,
            rgbTargets: rgbTargets
        )
        
        if success {
            saveAlertMessage = "Map saved successfully!"
        } else {
            saveAlertMessage = "Failed to save map."
        }
        showingSaveAlert = true
    }
    
    private func saveAsMap() {
        let ocrConfigs = getCurrentOCRConfigs()
        let success = TableMapIO.saveAsMap(
            regions: drawnRegions,
            ocrConfigs: ocrConfigs,
            rgbTargets: rgbTargets
        )
        
        if success {
            saveAlertMessage = "Map saved successfully!"
        } else {
            saveAlertMessage = "Failed to save map."
        }
        showingSaveAlert = true
    }
    
    // MARK: - Load Functions
    
    private func loadMap() {
        guard let loaded = TableMapIO.loadMap() else {
            saveAlertMessage = "Failed to load map."
            showingSaveAlert = true
            return
        }
        
        // Update regions
        drawnRegions = loaded.regions
        selectedRegionID = nil
        
        // Update OCR and RGB via callback
        onLoad(loaded.ocrConfigs, loaded.rgbTargets)
        
        saveAlertMessage = "Map loaded successfully!"
        showingSaveAlert = true
    }
    
    // MARK: - New Map
    
    private func newMap() {
        TableMapIO.newMap()
        drawnRegions = []
        selectedRegionID = nil
        
        // Reset to defaults via callback
        let defaultOCRConfigs = OCRConfigs(
            baseOCR: .default,
            playerBet: ocrService.playerBetConfig,  // Keep current defaults
            playerBalance: ocrService.playerBalanceConfig,
            playerAction: ocrService.playerActionConfig,
            tablePot: ocrService.tablePotConfig
        )
        onLoad(defaultOCRConfigs, RGBTargets.default)
    }
    
    // MARK: - Helper Functions
    
    private func getCurrentOCRConfigs() -> OCRConfigs {
        return OCRConfigs(
            baseOCR: ocrService.baseOCRConfig,
            playerBet: ocrService.playerBetConfig,
            playerBalance: ocrService.playerBalanceConfig,
            playerAction: ocrService.playerActionConfig,
            tablePot: ocrService.tablePotConfig
        )
    }
}

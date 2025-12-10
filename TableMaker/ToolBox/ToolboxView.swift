import SwiftUI

struct ToolboxView: View {
    @Binding var drawnRegions: [RegionBox]
    @Binding var selectedRegionID: UUID?
    @Binding var isCreatingRegion: Bool
    @Binding var regionsLocked: Bool
    var screenshot: NSImage

    @State private var width: Double = 0
    @State private var height: Double = 0
    @State private var xPosition: Double = 0
    @State private var yPosition: Double = 0

    @State private var ocrValue: String = ""
    @State private var averageColorHex: String = ""
    @State private var regionName: String = ""
    @State private var selectedOCRType: OCRType = .baseOCR
    @State private var ocrImage: NSImage?
    @State private var selectedRGBType: RGBType = .dealerButton
    @State private var rgbValue: String = ""
    
    @State private var ocrService = OCRService()
    @State private var showMLCards = false
    
    // RGB Service State
    @State private var rgbService = RGBService()
    @State private var rgbTargets = RGBTargets.default
    @State private var showRGBConfig = false
    
    // Rapid Collection State with Tag Popup
    @State private var rapidCollectionMode = false
    @State private var enhancedMode = false
    @State private var showRapidCollection = false
    @State private var showTagPopup = false
    @State private var pendingRegion: RegionBox?
    
    // Template Matching State
    @StateObject private var templateProcessor = TemplateCardProcessor()
    @State private var showTemplateMatching = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HeaderControlsView(
                    isCreatingRegion: $isCreatingRegion,
                    selectedRegionID: $selectedRegionID,
                    selectedOCRType: $selectedOCRType,
                    selectedRGBType: $selectedRGBType,
                    regionsLocked: $regionsLocked,
                    drawnRegions: drawnRegions,
                    screenshot: screenshot,
                    ocrValue: $ocrValue,
                    rgbValue: $rgbValue,
                    ocrService: $ocrService,
                    performOCR: performOCR,
                    performRGB: performRGB
                )
                
                // Show OCRParametersView for ALL OCR types
                OCRParametersView(
                    parameters: bindingForSelectedOCRType(),
                    ocrService: $ocrService,
                    selectedOCRType: selectedOCRType,
                    selectedRegionID: selectedRegionID,
                    drawnRegions: drawnRegions,
                    screenshot: screenshot,
                    onParametersChanged: updateOCRPreview
                )
                
                // ML Cards Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ML Cards")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showMLCards.toggle()
                        }) {
                            Image(systemName: showMLCards ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showMLCards {
                        MLTestView(
                            selectedRegion: selectedRegionID.flatMap { id in
                                drawnRegions.first { $0.id == id }
                            },
                            screenshot: screenshot
                        )
                    }
                }
                .padding(.vertical, 8)
                
                // RGB Configuration Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("RGB Configuration")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showRGBConfig.toggle()
                        }) {
                            Image(systemName: showRGBConfig ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showRGBConfig {
                        RGBConfigView(
                            rgbTargets: $rgbTargets,
                            rgbService: $rgbService,
                            selectedRegionID: selectedRegionID,
                            drawnRegions: drawnRegions,
                            screenshot: screenshot
                        )
                    }
                }
                .padding(.vertical, 8)
                
                // Template Matching Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Template Matching")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showTemplateMatching.toggle()
                        }) {
                            Image(systemName: showTemplateMatching ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showTemplateMatching {
                        TemplateMatchingView(
                            templateProcessor: templateProcessor,
                            selectedRegion: selectedRegionID.flatMap { id in
                                drawnRegions.first { $0.id == id }
                            },
                            screenshot: screenshot
                        )
                    }
                }
                .padding(.vertical, 8)
                
                // Rapid Collection Section with Card Tag System
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rapid Collection")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showRapidCollection.toggle()
                        }) {
                            Image(systemName: showRapidCollection ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showRapidCollection {
                        RapidCollectionView(
                            rapidCollectionMode: $rapidCollectionMode,
                            enhancedMode: $enhancedMode
                        )
                    }
                }
                .padding(.vertical, 8)
                
                MapControlsView(
                    drawnRegions: $drawnRegions,
                    selectedRegionID: $selectedRegionID,
                    ocrService: $ocrService,
                    rgbTargets: $rgbTargets,
                    onLoad: handleMapLoad
                )
                
                RegionListView(
                    drawnRegions: $drawnRegions,
                    selectedRegionID: $selectedRegionID
                )
                
                if let selectedRegionID = selectedRegionID,
                   let selectedRegion = drawnRegions.first(where: { $0.id == selectedRegionID }) {
                    RegionDetailsView(
                        selectedRegion: selectedRegion,
                        selectedRegionID: selectedRegionID,
                        drawnRegions: $drawnRegions,
                        regionName: $regionName,
                        width: $width,
                        height: $height,
                        xPosition: $xPosition,
                        yPosition: $yPosition,
                        screenshot: screenshot,
                        ocrValue: ocrValue,
                        averageColorHex: averageColorHex,
                        rgbValue: rgbValue,
                        selectedOCRType: selectedOCRType,
                        ocrService: ocrService
                    )
                }
            }
            .padding()
        }
        .frame(maxWidth: 300)
        .overlay(
            // Tag Selection Popup
            Group {
                if showTagPopup {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showTagPopup = false
                            pendingRegion = nil
                        }
                    
                    CardTagPopupView(
                        onTagSelected: { tag in
                            handleTagSelection(tag: tag)
                        },
                        onCancel: {
                            showTagPopup = false
                            pendingRegion = nil
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showTagPopup)
        )
        .onAppear {
            updateStateForSelectedRegion()
        }
        .onChange(of: selectedRegionID) { _ in
            updateStateForSelectedRegion()
            handleRapidCollectionForSelectedRegion()
        }
        .onChange(of: drawnRegions) { _ in
            updateStateForSelectedRegion()
        }
        .onChange(of: selectedOCRType) { _ in
            updateStateForSelectedRegion()
        }
        .onChange(of: rgbTargets) { newTargets in
            rgbService.targets = newTargets
        }
    }

    // MARK: - Helper Functions
    
    /// Get binding for the currently selected OCR type's config
    private func bindingForSelectedOCRType() -> Binding<OCRParameters> {
        switch selectedOCRType {
        case .baseOCR:
            return $ocrService.baseOCRConfig
        case .playerBet:
            return $ocrService.playerBetConfig
        case .playerBalance:
            return $ocrService.playerBalanceConfig
        case .playerAction:
            return $ocrService.playerActionConfig
        case .tablePot:
            return $ocrService.tablePotConfig
        }
    }
    
    private func updateStateForSelectedRegion() {
        print("SelectedRegionID: \(String(describing: selectedRegionID))")

        if let id = selectedRegionID,
           let region = drawnRegions.first(where: { $0.id == id }) {
            print("Matched Region: \(region.name)")
            DispatchQueue.main.async {
                width = region.rect.size.width
                height = region.rect.size.height
                xPosition = region.rect.origin.x
                yPosition = region.rect.origin.y
                regionName = region.name
            }
            
            // Perform OCR with selected type
            performOCR(for: selectedOCRType, in: region)
            
            let avgHex = ocrService.averageColorString(in: screenshot, for: region) ?? ""
            DispatchQueue.main.async {
                averageColorHex = avgHex
                rgbValue = ""
            }
        }
    }
    
    private func handleRapidCollectionForSelectedRegion() {
        guard rapidCollectionMode,
              let id = selectedRegionID,
              let region = drawnRegions.first(where: { $0.id == id }) else { return }
        
        pendingRegion = region
        showTagPopup = true
    }
    
    private func handleTagSelection(tag: String) {
        guard let region = pendingRegion else { return }
        
        showTagPopup = false
        pendingRegion = nil
        
        let success = RapidCollectionManager.shared.taggedSave(
            screenshot: screenshot,
            region: region,
            tag: tag,
            enhancedMode: enhancedMode
        )
        
        if success {
            let imageCount = enhancedMode ? "7 images" : "1 image"
            print("Tagged rapid collection complete: \(region.name) -> \(tag) (\(imageCount))")
        } else {
            print("Tagged rapid collection failed for: \(region.name) -> \(tag)")
        }
    }
    
    private func updateOCRPreview() {
        updateStateForSelectedRegion()
    }
    
    private func handleMapLoad(ocrConfigs: OCRConfigs, rgbTargets: RGBTargets) {
        // Update OCR configs
        ocrService.baseOCRConfig = ocrConfigs.baseOCR
        ocrService.playerBetConfig = ocrConfigs.playerBet
        ocrService.playerBalanceConfig = ocrConfigs.playerBalance
        ocrService.playerActionConfig = ocrConfigs.playerAction
        ocrService.tablePotConfig = ocrConfigs.tablePot
        
        // Update RGB targets
        self.rgbTargets = rgbTargets
        self.rgbService.targets = rgbTargets
        
        print("✅ Loaded OCR configs and RGB targets into services")
    }

    private func performOCR(for type: OCRType, in region: RegionBox) {
        switch type {
        case .baseOCR:
            ocrService.readValue(in: screenshot, for: region) { value in
                DispatchQueue.main.async {
                    ocrValue = value ?? ""
                }
            }
        case .playerBet:
            ocrService.readPlayerBet(in: screenshot, for: region) { image, value in
                DispatchQueue.main.async {
                    ocrImage = image
                    ocrValue = value
                }
            }
        case .playerBalance:
            ocrService.readPlayerBalance(in: screenshot, for: region) { image, value in
                DispatchQueue.main.async {
                    ocrImage = image
                    ocrValue = value
                }
            }
        case .playerAction:
            ocrService.readPlayerAction(in: screenshot, for: region) { image, value in
                DispatchQueue.main.async {
                    ocrImage = image
                    ocrValue = value
                }
            }
        case .tablePot:
            ocrService.readTablePot(in: screenshot, for: region) { image, value in
                DispatchQueue.main.async {
                    ocrImage = image
                    ocrValue = value
                }
            }
        }
    }
    
    private func performRGB(for type: RGBType, in region: RegionBox) {
        switch type {
        case .dealerButton:
            rgbValue = rgbService.checkDealerButton(in: screenshot, for: region) ? "Dealer Button" : "No Match"
        case .cardBack:
            rgbValue = rgbService.checkCardBack(in: screenshot, for: region) ? "Card Back" : "No Match"
        case .cardSuit:
            rgbValue = rgbService.detectCardSuit(in: screenshot, for: region)?.rawValue ?? "Unknown"
        }
    }
}

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
    @State private var selectedOCRType: OCRType = .cardRank
    @State private var ocrImage: NSImage?
    @State private var selectedRGBType: RGBType = .dealerButton
    @State private var rgbValue: String = ""
    
    @State private var ocrParameters = OCRParameters.default
    @State private var ocrService = OCRService()
    @State private var showTrainingDataCollection = false
    @State private var showCoreMlDataCollection = false
    @State private var showMLCards = false
    
    // Rapid Collection State with Tag Popup
    @State private var rapidCollectionMode = false
    @State private var enhancedMode = false
    @State private var showRapidCollection = false
    @State private var showTagPopup = false
    @State private var pendingRegion: RegionBox?

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
                
                if selectedOCRType == .baseOCR {
                    OCRParametersView(
                        parameters: $ocrParameters,
                        ocrService: $ocrService,
                        selectedRegionID: selectedRegionID,
                        drawnRegions: drawnRegions,
                        screenshot: screenshot,
                        onParametersChanged: updateOCRPreview
                    )
                }
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
                
                // Training Data Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("OCR Training Data")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showTrainingDataCollection.toggle()
                        }) {
                            Image(systemName: showTrainingDataCollection ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showTrainingDataCollection {
                        TrainingDataView(
                            selectedRegion: selectedRegionID.flatMap { id in
                                drawnRegions.first { $0.id == id }
                            },
                            screenshot: screenshot,
                            selectedOCRType: selectedOCRType,
                            ocrService: ocrService
                        )
                    }
                }
                .padding(.vertical, 8)
                
                // CoreML Data Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CoreML Training Data")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showCoreMlDataCollection.toggle()
                        }) {
                            Image(systemName: showCoreMlDataCollection ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showCoreMlDataCollection {
                        CoreMLDataView(
                            selectedRegion: selectedRegionID.flatMap { id in
                                drawnRegions.first { $0.id == id }
                            },
                            screenshot: screenshot
                        )
                    }
                }
                .padding(.vertical, 8)
                
                MapControlsView(drawnRegions: $drawnRegions, selectedRegionID: $selectedRegionID)
                
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
            
            // Handle rapid collection with tag popup system
            handleRapidCollectionForSelectedRegion()
        }
        .onChange(of: drawnRegions) { _ in
            updateStateForSelectedRegion()
        }
        .onChange(of: ocrParameters) { _ in
            ocrService.updateBaseOCRParameters(ocrParameters)
        }
        .onChange(of: selectedOCRType) { _ in
            updateStateForSelectedRegion()
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
            
            ocrService.updateBaseOCRParameters(ocrParameters)
            
            ocrService.readValue(in: screenshot, for: region) { value in
                DispatchQueue.main.async {
                    ocrValue = value ?? ""
                }
            }
            let avgHex = ocrService.averageColorString(in: screenshot, for: region) ?? ""
            DispatchQueue.main.async {
                averageColorHex = avgHex
                rgbValue = ""
            }
        }
    }
    
    // Handle rapid collection with tag popup system
    private func handleRapidCollectionForSelectedRegion() {
        guard rapidCollectionMode,
              let id = selectedRegionID,
              let region = drawnRegions.first(where: { $0.id == id }) else { return }
        
        // Store the region and show tag popup
        pendingRegion = region
        showTagPopup = true
    }
    
    // Handle tag selection and save images
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

    private func performOCR(for type: OCRType, in region: RegionBox) {
        switch type {
        case .baseOCR:
            ocrService.readValue(in: screenshot, for: region) { value in
                DispatchQueue.main.async {
                    ocrValue = value ?? ""
                }
            }
        case .cardRank:
            ocrService.readCardRank(in: screenshot, for: region) { image, value in
                DispatchQueue.main.async {
                    ocrImage = image
                    ocrValue = value
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
        let service = RGB()
        switch type {
        case .dealerButton:
            rgbValue = service.checkDealerButton(in: screenshot, for: region) ? "Dealer Button" : "No Match"
        case .cardBack:
            rgbValue = service.checkCardBack(in: screenshot, for: region) ? "Card Back" : "No Match"
        case .cardSuit:
            rgbValue = service.detectCardSuit(in: screenshot, for: region)?.rawValue ?? "Unknown"
        }
    }
}

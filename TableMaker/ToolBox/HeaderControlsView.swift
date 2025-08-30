import SwiftUI

//Select OCR MODE and RGB Mode

//Currenly these are only hard coded variables, future update user can generate and tag modes for custom env's
struct HeaderControlsView: View {
    @Binding var isCreatingRegion: Bool
    @Binding var selectedRegionID: UUID?
    @Binding var selectedOCRType: OCRType
    @Binding var selectedRGBType: RGBType
    @Binding var regionsLocked: Bool
    let drawnRegions: [RegionBox]
    let screenshot: NSImage
    @Binding var ocrValue: String
    @Binding var rgbValue: String
    @Binding var ocrService: OCRService
    let performOCR: (OCRType, RegionBox) -> Void
    let performRGB: (RGBType, RegionBox) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Lock Regions", isOn: $regionsLocked)
                .toggleStyle(.button)
                .padding(.vertical, 8)

            Button(action: {
                isCreatingRegion = true
                selectedRegionID = nil
            }) {
                Label("New Region", systemImage: "plus.rectangle")
            }
            .buttonStyle(.borderedProminent)

            Picker("OCR Mode", selection: $selectedOCRType) {
                Text("Base OCR").tag(OCRType.baseOCR)
                Text("Card Rank").tag(OCRType.cardRank)
                Text("Player Bet").tag(OCRType.playerBet)
                Text("Player Balance").tag(OCRType.playerBalance)
                Text("Player Action").tag(OCRType.playerAction)
                Text("Table Pot").tag(OCRType.tablePot)
            }
            .pickerStyle(.menu)

            Picker("RGB Mode", selection: $selectedRGBType) {
                Text("Dealer Button").tag(RGBType.dealerButton)
                Text("Card Back").tag(RGBType.cardBack)
                Text("Card Suit").tag(RGBType.cardSuit)
            }
            .pickerStyle(.menu)

            Button("Run OCR") {
                if let id = selectedRegionID,
                   let region = drawnRegions.first(where: { $0.id == id }) {
                    performOCR(selectedOCRType, region)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedRegionID == nil)
            .padding(.top, 8)
            
            Button("Run RGB") {
                if let id = selectedRegionID,
                   let region = drawnRegions.first(where: { $0.id == id }) {
                    performRGB(selectedRGBType, region)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedRegionID == nil)
            .padding(.top, 8)
        }
    }
}

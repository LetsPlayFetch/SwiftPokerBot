import SwiftUI

struct RegionDetailsView: View {
    let selectedRegion: RegionBox
    let selectedRegionID: UUID
    @Binding var drawnRegions: [RegionBox]
    @Binding var regionName: String
    @Binding var width: Double
    @Binding var height: Double
    @Binding var xPosition: Double
    @Binding var yPosition: Double
    let screenshot: NSImage
    let ocrValue: String
    let averageColorHex: String
    let rgbValue: String
    let selectedOCRType: OCRType
    let ocrService: OCRService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RegionNameFieldView(
                regionName: $regionName,
                selectedRegionID: selectedRegionID,
                drawnRegions: $drawnRegions
            )
            
            RegionControlsView(
                selectedRegionID: selectedRegionID,
                drawnRegions: $drawnRegions,
                width: $width,
                height: $height,
                xPosition: $xPosition,
                yPosition: $yPosition
            )
            
            RegionPreviewsView(
                selectedRegion: selectedRegion,
                screenshot: screenshot,
                selectedOCRType: selectedOCRType,
                ocrService: ocrService
            )
            
            RegionInfoView(
                ocrValue: ocrValue,
                averageColorHex: averageColorHex,
                rgbValue: rgbValue
            )
        }
    }
}

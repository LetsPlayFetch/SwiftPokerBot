import SwiftUI

struct RegionControlsView: View {
    let selectedRegionID: UUID
    @Binding var drawnRegions: [RegionBox]
    @Binding var width: Double
    @Binding var height: Double
    @Binding var xPosition: Double
    @Binding var yPosition: Double

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            SizeControlsView(
                selectedRegionID: selectedRegionID,
                drawnRegions: $drawnRegions,
                width: $width,
                height: $height
            )
            
            PositionControlsView(
                selectedRegionID: selectedRegionID,
                drawnRegions: $drawnRegions,
                xPosition: $xPosition,
                yPosition: $yPosition
            )
        }
    }
}

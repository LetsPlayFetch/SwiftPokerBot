import SwiftUI

struct RegionEditorView: View {
    let image: NSImage
    
    @State private var drawnRegions: [RegionBox] = []
    @State private var selectedRegionID: UUID?
    @State private var isCreatingRegion: Bool = false
    @State private var regionsLocked: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Toolbox - always visible on the left
            ToolboxView(
                drawnRegions: $drawnRegions,
                selectedRegionID: $selectedRegionID,
                isCreatingRegion: $isCreatingRegion,
                regionsLocked: $regionsLocked,
                screenshot: image
            )
            .background(Color(NSColor.controlBackgroundColor))
            
            // Main canvas area
            ImageCanvas(
                drawnRegions: $drawnRegions,
                selectedRegionID: $selectedRegionID,
                isCreatingRegion: $isCreatingRegion,
                regionsLocked: $regionsLocked,
                image: image
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

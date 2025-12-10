import SwiftUI
import AppKit

struct ImageCanvas: View {
    @Binding var drawnRegions: [RegionBox]
    @Binding var selectedRegionID: UUID?
    @Binding var isCreatingRegion: Bool
    @Binding var regionsLocked: Bool
    var image: NSImage

    @State private var currentRect: CGRect? = nil
    @State private var startLocation: CGPoint? = nil
    @State private var dragOffsets: [UUID: CGSize] = [:]
    
    var body: some View {
        GeometryReader { geometry in
            
            // Scale displayed Img based on screen size
            let scaleX = geometry.size.width / image.size.width
            let scaleY = geometry.size.height / image.size.height
            let scale = min(scaleX, scaleY)
            
            // Center img
            let imageSizeScaled = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let offsetX = (geometry.size.width - imageSizeScaled.width) / 2
            let offsetY = (geometry.size.height - imageSizeScaled.height) / 2

            // Simple image size debug
            let _ = print("📐 Image size: \(image.size.width) × \(image.size.height)")

            let scaledGesture = DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let loc = CGPoint(
                        x: (value.location.x - offsetX) / scale,
                        y: (value.location.y - offsetY) / scale
                    )
                    if startLocation == nil {
                        startLocation = loc
                    }
                    let origin = startLocation ?? .zero
                    currentRect = CGRect(
                        x: min(origin.x, loc.x),
                        y: min(origin.y, loc.y),
                        width: abs(loc.x - origin.x),
                        height: abs(loc.y - origin.y)
                    )
                }
                .onEnded { value in
                    let loc = CGPoint(
                        x: (value.location.x - offsetX) / scale,
                        y: (value.location.y - offsetY) / scale
                    )
                    if let origin = startLocation {
                        let rect = CGRect(
                            x: min(origin.x, loc.x),
                            y: min(origin.y, loc.y),
                            width: abs(loc.x - origin.x),
                            height: abs(loc.y - origin.y)
                        )
                        let newBox = RegionBox(id: UUID(), name: "New Region", rect: rect)
                        drawnRegions.append(newBox)
                        selectedRegionID = newBox.id
                    }
                    currentRect = nil
                    startLocation = nil
                    isCreatingRegion = false
                }

            ZStack(alignment: .topLeading) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: imageSizeScaled.width, height: imageSizeScaled.height)

                // Draw saved boxes
                ForEach(drawnRegions) { region in
                    let dragOffset = dragOffsets[region.id] ?? .zero

                    let dragGesture = regionsLocked ? nil : DragGesture()
                        .onChanged { value in
                            dragOffsets[region.id] = value.translation
                        }
                        .onEnded { value in
                            let deltaX = value.translation.width / scale
                            let deltaY = value.translation.height / scale
                            if let index = drawnRegions.firstIndex(where: { $0.id == region.id }) {
                                drawnRegions[index].rect.origin.x += deltaX
                                drawnRegions[index].rect.origin.y += deltaY
                            }
                            dragOffsets[region.id] = .zero
                        }

                    Rectangle()
                        .stroke(region.id == selectedRegionID ? Color.green : Color.red, lineWidth: 2)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: region.rect.width * scale, height: region.rect.height * scale)
                        .position(x: region.rect.midX * scale, y: region.rect.midY * scale)
                        .offset(dragOffset)
                        .onTapGesture {
                            selectedRegionID = region.id
                        }
                        .gesture(dragGesture)
                }

                // Draw current drag box
                if let rect = currentRect {
                    Rectangle()
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(width: rect.width * scale, height: rect.height * scale)
                        .position(x: rect.midX * scale, y: rect.midY * scale)
                }
            }
            .offset(x: offsetX, y: offsetY)
            .gesture(isCreatingRegion ? scaledGesture : nil)
        }
    }
}

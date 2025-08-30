import SwiftUI

struct RegionListView: View {
    @Binding var drawnRegions: [RegionBox]
    @Binding var selectedRegionID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Regions")
                .font(.headline)
            
            List(selection: $selectedRegionID) {
                ForEach(drawnRegions.sorted(by: { $0.name < $1.name })) { region in
                    Text(region.name)
                        .tag(region.id)
                }
                .onDelete { offsets in
                    let sortedList = drawnRegions.sorted(by: { $0.name < $1.name })
                    let idsToRemove = offsets.map { sortedList[$0].id }
                    drawnRegions.removeAll { idsToRemove.contains($0.id) }
                }
            }
            .frame(minHeight: 150)
        }
    }
}

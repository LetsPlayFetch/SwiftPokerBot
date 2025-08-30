import SwiftUI

struct RegionNameFieldView: View {
    @Binding var regionName: String
    let selectedRegionID: UUID
    @Binding var drawnRegions: [RegionBox]

    var body: some View {
        HStack {
            Text("Name:")
                .frame(width: 60, alignment: .leading)
            TextField("Region Name", text: $regionName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: regionName) { newName in
                    if let index = drawnRegions.firstIndex(where: { $0.id == selectedRegionID }) {
                        drawnRegions[index].name = newName
                    }
                }
        }
        .font(.headline)
        .padding(.bottom, 8)
    }
}

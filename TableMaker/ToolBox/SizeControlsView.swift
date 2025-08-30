import SwiftUI

struct SizeControlsView: View {
    let selectedRegionID: UUID
    @Binding var drawnRegions: [RegionBox]
    @Binding var width: Double
    @Binding var height: Double

    var body: some View {
        VStack(spacing: 16) {
            // Width control
            HStack(spacing: 8) {
                Text("Width")
                    .frame(width: 48, alignment: .leading)
                Stepper(value: $width, in: 1...1000, step: 1) { }
                    .onChange(of: width) { newValue in
                        updateWidth(newValue)
                    }
                TextField("", value: $width, format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .onChange(of: width) { newValue in
                        updateWidth(newValue)
                    }
            }

            // Height control
            HStack(spacing: 8) {
                Text("Height")
                    .frame(width: 48, alignment: .leading)
                Stepper(value: $height, in: 1...1000, step: 1) { }
                    .onChange(of: height) { newValue in
                        updateHeight(newValue)
                    }
                TextField("", value: $height, format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .onChange(of: height) { newValue in
                        updateHeight(newValue)
                    }
            }
        }
    }
    
    private func updateWidth(_ newValue: Double) {
        DispatchQueue.main.async {
            let intVal = Double(Int(newValue))
            guard let index = self.drawnRegions.firstIndex(where: { $0.id == self.selectedRegionID }),
                  index < self.drawnRegions.count else { return }
            self.drawnRegions[index].rect.size.width = intVal
            self.width = intVal
        }
    }
    
    private func updateHeight(_ newValue: Double) {
        DispatchQueue.main.async {
            let intVal = Double(Int(newValue))
            guard let index = self.drawnRegions.firstIndex(where: { $0.id == self.selectedRegionID }),
                  index < self.drawnRegions.count else { return }
            self.drawnRegions[index].rect.size.height = intVal
            self.height = intVal
        }
    }
}

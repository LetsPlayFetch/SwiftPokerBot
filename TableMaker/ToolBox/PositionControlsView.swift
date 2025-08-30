import SwiftUI

/// Shift regions
struct PositionControlsView: View {
    let selectedRegionID: UUID
    @Binding var drawnRegions: [RegionBox]
    @Binding var xPosition: Double
    @Binding var yPosition: Double

    var body: some View {
        VStack(spacing: 16) {
            // X Position control
            HStack(spacing: 8) {
                Text("X")
                    .frame(width: 48, alignment: .leading)
                Stepper(value: $xPosition, in: -1000...2000, step: 1) { }
                    .onChange(of: xPosition) { newValue in
                        updateXPosition(newValue)
                    }
                TextField("", value: $xPosition, format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .onChange(of: xPosition) { newValue in
                        updateXPosition(newValue)
                    }
            }

            // Y Position control
            HStack(spacing: 8) {
                Text("Y")
                    .frame(width: 48, alignment: .leading)
                Stepper(value: $yPosition, in: -1000...2000, step: 1) { }
                    .onChange(of: yPosition) { newValue in
                        updateYPosition(newValue)
                    }
                TextField("", value: $yPosition, format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .onChange(of: yPosition) { newValue in
                        updateYPosition(newValue)
                    }
            }
        }
    }
    
    private func updateXPosition(_ newValue: Double) {
        DispatchQueue.main.async {
            let intVal = Double(Int(newValue))
            guard let index = self.drawnRegions.firstIndex(where: { $0.id == self.selectedRegionID }),
                  index < self.drawnRegions.count else { return }
            self.drawnRegions[index].rect.origin.x = intVal
            self.xPosition = intVal
        }
    }
    
    private func updateYPosition(_ newValue: Double) {
        DispatchQueue.main.async {
            let intVal = Double(Int(newValue))
            guard let index = self.drawnRegions.firstIndex(where: { $0.id == self.selectedRegionID }),
                  index < self.drawnRegions.count else { return }
            self.drawnRegions[index].rect.origin.y = intVal
            self.yPosition = intVal
        }
    }
}

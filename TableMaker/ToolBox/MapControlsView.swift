import SwiftUI

struct MapControlsView: View {
    @Binding var drawnRegions: [RegionBox]
    @Binding var selectedRegionID: UUID?
    
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    let success = TableMapIO.saveMap(drawnRegions)
                    if success {
                        saveAlertMessage = "Map saved successfully!"
                    } else {
                        saveAlertMessage = "Failed to save map."
                    }
                    showingSaveAlert = true
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .help(TableMapIO.hasCurrentFile() ?
                      "Save to \(TableMapIO.getCurrentFileName())" :
                      "Save (will prompt for location)")
                
                Button(action: {
                    let success = TableMapIO.saveAsMap(drawnRegions)
                    if success {
                        saveAlertMessage = "Map saved successfully!"
                    } else {
                        saveAlertMessage = "Failed to save map."
                    }
                    showingSaveAlert = true
                }) {
                    Label("Save As", systemImage: "square.and.arrow.down.on.square")
                }
                .help("Save with a new name or location")
            }
            
            HStack {
                Button(action: {
                    if let loaded = TableMapIO.loadMap() {
                        drawnRegions = loaded
                        selectedRegionID = nil
                    }
                }) {
                    Label("Load Map", systemImage: "arrow.down.doc")
                }
                
                Button(action: {
                    TableMapIO.newMap()
                    drawnRegions = []
                    selectedRegionID = nil
                }) {
                    Label("New", systemImage: "doc")
                }
                .help("Create a new map (clears current regions)")
            }
        }
        .buttonStyle(.bordered)
        .alert("Save Status", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text(saveAlertMessage)
        }
    }
}

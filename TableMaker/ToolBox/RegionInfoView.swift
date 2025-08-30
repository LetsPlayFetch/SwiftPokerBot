import SwiftUI

///refresh on region and speciifc clicks 
struct RegionInfoView: View {
    let ocrValue: String
    let averageColorHex: String
    let rgbValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OCR Value:")
                    .font(.subheadline)
                Text(ocrValue.isEmpty ? "N/A" : ocrValue)
                    .padding(6)
                    .frame(minWidth: 120)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            HStack {
                Text("Average Color:")
                    .font(.subheadline)
                Text(averageColorHex.isEmpty ? "N/A" : averageColorHex)
                    .padding(6)
                    .frame(minWidth: 120)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            HStack {
                Text("RGB Value:")
                    .font(.subheadline)
                Text(rgbValue.isEmpty ? "N/A" : rgbValue)
                    .padding(6)
                    .frame(minWidth: 120)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(.top, 12)
    }
}

import SwiftUI

struct RegionPreviewsView: View {
    let selectedRegion: RegionBox
    let screenshot: NSImage
    let selectedOCRType: OCRType
    let ocrService: OCRService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Region: \(selectedRegion.name)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let cropped = ocrService.croppedImage(in: screenshot, for: selectedRegion) {
                Text("Preview cropped image")
                    .font(.headline)
                    .padding(.top, 8)
                Image(nsImage: cropped)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
            } else {
                Text("Cropped image is nil")
                    .foregroundColor(.red)
            }

            let processed: NSImage? = {
                switch selectedOCRType {
                case .baseOCR:
                    return ocrService.preprocessedImage(in: screenshot, for: selectedRegion)
                case .cardRank:
                    return CardRankOCR().preprocessedPreviewImage(from: screenshot, region: selectedRegion)
                case .playerBet:
                    return PlayerBetOCR().preprocessedPreviewImage(from: screenshot, region: selectedRegion)
                case .playerBalance:
                    return PlayerBalanceOCR().preprocessedPreviewImage(from: screenshot, region: selectedRegion)
                case .playerAction:
                    return PlayerActionOCR().preprocessedPreviewImage(from: screenshot, region: selectedRegion)
                case .tablePot:
                    return TablePotOCR().preprocessedPreviewImage(from: screenshot, region: selectedRegion)
                }
            }()

            if let processed {
                Text("Processed Preview")
                    .font(.headline)
                    .padding(.top, 8)
                Image(nsImage: processed)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
            } else {
                Text("Processed image is nil")
                    .foregroundColor(.red)
            }
        }
    }
}

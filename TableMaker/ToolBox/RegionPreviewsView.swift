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

            // FIX: Use'd configs from ocrService instead of creating new instances
            let processed: NSImage? = {
                guard let cropCI = ImageUtilities.cropROI(screenshot, rect: selectedRegion.rect) else {
                    return nil
                }
                
                let config: OCRParameters
                switch selectedOCRType {
                case .baseOCR:
                    config = ocrService.baseOCRConfig
                case .playerBet:
                    config = ocrService.playerBetConfig
                case .playerBalance:
                    config = ocrService.playerBalanceConfig
                case .playerAction:
                    config = ocrService.playerActionConfig
                case .tablePot:
                    config = ocrService.tablePotConfig
                }
                
                let processedCI = OCRPreprocessor.preprocess(image: cropCI, config: config)
                return ImageUtilities.ciToNSImage(processedCI)
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

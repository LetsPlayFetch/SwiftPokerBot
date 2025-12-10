import SwiftUI

/// UI for configuring RGB target colors - captures detected colors instead of manual selection
struct RGBConfigView: View {
    @Binding var rgbTargets: RGBTargets
    @Binding var rgbService: RGBService
    let selectedRegionID: UUID?
    let drawnRegions: [RegionBox]
    let screenshot: NSImage
    
    @State private var detectedColor: RGBColor?
    @State private var matchResult: String = ""
    @State private var saveResult: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RGB Target Colors")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Dealer Button
            VStack(alignment: .leading, spacing: 8) {
                Text("Dealer Button")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    // Color swatch (read-only)
                    Rectangle()
                        .fill(Color(rgbTargets.dealerButton.nsColor))
                        .frame(width: 40, height: 40)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    
                    // RGB values (read-only)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("R: \(String(format: "%.2f", rgbTargets.dealerButton.r))")
                            .font(.caption)
                            .monospaced()
                        Text("G: \(String(format: "%.2f", rgbTargets.dealerButton.g))")
                            .font(.caption)
                            .monospaced()
                        Text("B: \(String(format: "%.2f", rgbTargets.dealerButton.b))")
                            .font(.caption)
                            .monospaced()
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Button("Save") {
                            saveDealerButton()
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedRegionID == nil)
                        
                        Button("Test") {
                            testDealerButton()
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedRegionID == nil)
                    }
                }
                
                if let region = selectedRegion {
                    Text("Region: \(region.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Card Back
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Back")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color(rgbTargets.cardBack.nsColor))
                        .frame(width: 40, height: 40)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("R: \(String(format: "%.2f", rgbTargets.cardBack.r))")
                            .font(.caption)
                            .monospaced()
                        Text("G: \(String(format: "%.2f", rgbTargets.cardBack.g))")
                            .font(.caption)
                            .monospaced()
                        Text("B: \(String(format: "%.2f", rgbTargets.cardBack.b))")
                            .font(.caption)
                            .monospaced()
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Button("Save") {
                            saveCardBack()
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedRegionID == nil)
                        
                        Button("Test") {
                            testCardBack()
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedRegionID == nil)
                    }
                }
            }
            
            Divider()
            
            // Card Suits
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Suits")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach([Suit.hearts, Suit.diamonds, Suit.clubs, Suit.spades], id: \.self) { suit in
                    HStack(spacing: 12) {
                        Text(suitName(suit))
                            .frame(width: 70, alignment: .leading)
                        
                        Rectangle()
                            .fill(Color((rgbTargets.cardSuits[suit] ?? RGBColor(r: 1, g: 1, b: 1)).nsColor))
                            .frame(width: 30, height: 30)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        
                        if let color = rgbTargets.cardSuits[suit] {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("R:\(String(format: "%.2f", color.r))")
                                    .font(.caption2)
                                    .monospaced()
                                Text("G:\(String(format: "%.2f", color.g))")
                                    .font(.caption2)
                                    .monospaced()
                                Text("B:\(String(format: "%.2f", color.b))")
                                    .font(.caption2)
                                    .monospaced()
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Button("Save") {
                                saveCardSuit(suit)
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedRegionID == nil)
                            
                            Button("Test") {
                                testCardSuit(suit)
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedRegionID == nil)
                        }
                    }
                }
            }
            
            Divider()
            
            // Tolerance Setting
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tolerance")
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    Text(String(format: "%.0f%%", rgbService.tolerance * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(rgbService.tolerance) },
                    set: { rgbService.tolerance = Float($0) }
                ), in: 0.0...0.3, step: 0.01) {
                    Text("Tolerance")
                }
            }
            
            // Save Result
            if !saveResult.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save Result:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(saveResult)
                        .font(.caption)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(.top, 8)
            }
            
            // Test Results
            if !matchResult.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Test Result:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(matchResult)
                        .font(.caption)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(.top, 8)
            }
            
            Button("Reset to Defaults") {
                rgbTargets = .default
                rgbService.targets = .default
                matchResult = ""
                saveResult = "Reset to defaults"
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onChange(of: rgbTargets) { newTargets in
            rgbService.targets = newTargets
        }
    }
    
    // MARK: - Helper Properties
    
    private var selectedRegion: RegionBox? {
        guard let id = selectedRegionID else { return nil }
        return drawnRegions.first { $0.id == id }
    }
    
    // MARK: - Save Functions
    
    private func saveDealerButton() {
        guard let region = selectedRegion else { return }
        
        if let detected = rgbService.getDetectedRGBColor(in: screenshot, for: region) {
            rgbTargets.dealerButton = detected
            saveResult = "✅ Dealer Button saved: R:\(String(format: "%.2f", detected.r)) G:\(String(format: "%.2f", detected.g)) B:\(String(format: "%.2f", detected.b))"
            matchResult = ""
            print("💾 Saved Dealer Button RGB: \(detected)")
        } else {
            saveResult = "❌ Failed to detect color in region"
        }
    }
    
    private func saveCardBack() {
        guard let region = selectedRegion else { return }
        
        if let detected = rgbService.getDetectedRGBColor(in: screenshot, for: region) {
            rgbTargets.cardBack = detected
            saveResult = "✅ Card Back saved: R:\(String(format: "%.2f", detected.r)) G:\(String(format: "%.2f", detected.g)) B:\(String(format: "%.2f", detected.b))"
            matchResult = ""
            print("💾 Saved Card Back RGB: \(detected)")
        } else {
            saveResult = "❌ Failed to detect color in region"
        }
    }
    
    private func saveCardSuit(_ suit: Suit) {
        guard let region = selectedRegion else { return }
        
        if let detected = rgbService.getDetectedRGBColor(in: screenshot, for: region) {
            rgbTargets.cardSuits[suit] = detected
            saveResult = "✅ \(suitName(suit)) saved: R:\(String(format: "%.2f", detected.r)) G:\(String(format: "%.2f", detected.g)) B:\(String(format: "%.2f", detected.b))"
            matchResult = ""
            print("💾 Saved \(suitName(suit)) RGB: \(detected)")
        } else {
            saveResult = "❌ Failed to detect color in region"
        }
    }
    
    // MARK: - Test Functions
    
    private func testDealerButton() {
        guard let region = selectedRegion else { return }
        
        let matches = rgbService.checkDealerButton(in: screenshot, for: region)
        
        if let detected = rgbService.getDetectedRGBColor(in: screenshot, for: region) {
            let target = rgbTargets.dealerButton
            let (_, diff) = rgbService.testColorMatch(detected: detected.nsColor, target: target.nsColor)
            
            matchResult = """
            Dealer Button: \(matches ? "✅ MATCH" : "❌ NO MATCH")
            Detected: R:\(String(format: "%.2f", detected.r)) G:\(String(format: "%.2f", detected.g)) B:\(String(format: "%.2f", detected.b))
            Target: R:\(String(format: "%.2f", target.r)) G:\(String(format: "%.2f", target.g)) B:\(String(format: "%.2f", target.b))
            Max Difference: \(String(format: "%.1f%%", diff * 100))
            """
            saveResult = ""
        }
    }
    
    private func testCardBack() {
        guard let region = selectedRegion else { return }
        
        let matches = rgbService.checkCardBack(in: screenshot, for: region)
        
        if let detected = rgbService.getDetectedRGBColor(in: screenshot, for: region) {
            let target = rgbTargets.cardBack
            let (_, diff) = rgbService.testColorMatch(detected: detected.nsColor, target: target.nsColor)
            
            matchResult = """
            Card Back: \(matches ? "✅ MATCH" : "❌ NO MATCH")
            Detected: R:\(String(format: "%.2f", detected.r)) G:\(String(format: "%.2f", detected.g)) B:\(String(format: "%.2f", detected.b))
            Target: R:\(String(format: "%.2f", target.r)) G:\(String(format: "%.2f", target.g)) B:\(String(format: "%.2f", target.b))
            Max Difference: \(String(format: "%.1f%%", diff * 100))
            """
            saveResult = ""
        }
    }
    
    private func testCardSuit(_ suit: Suit) {
        guard let region = selectedRegion else { return }
        
        let detectedSuit = rgbService.detectCardSuit(in: screenshot, for: region)
        let matches = detectedSuit == suit
        
        if let detected = rgbService.getDetectedRGBColor(in: screenshot, for: region),
           let target = rgbTargets.cardSuits[suit] {
            let (_, diff) = rgbService.testColorMatch(detected: detected.nsColor, target: target.nsColor)
            
            matchResult = """
            \(suitName(suit)): \(matches ? "✅ MATCH" : "❌ NO MATCH")
            Detected Suit: \(detectedSuit?.rawValue ?? "None")
            Detected: R:\(String(format: "%.2f", detected.r)) G:\(String(format: "%.2f", detected.g)) B:\(String(format: "%.2f", detected.b))
            Target: R:\(String(format: "%.2f", target.r)) G:\(String(format: "%.2f", target.g)) B:\(String(format: "%.2f", target.b))
            Max Difference: \(String(format: "%.1f%%", diff * 100))
            """
            saveResult = ""
        }
    }
    
    private func suitName(_ suit: Suit) -> String {
        switch suit {
        case .hearts: return "♥️ Hearts"
        case .diamonds: return "♦️ Diamonds"
        case .clubs: return "♣️ Clubs"
        case .spades: return "♠️ Spades"
        }
    }
}

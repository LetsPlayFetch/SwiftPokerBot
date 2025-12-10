import SwiftUI

/// Display for processing options - now works for ALL OCR types
struct OCRParametersView: View {
    @Binding var parameters: OCRParameters
    @Binding var ocrService: OCRService
    let selectedOCRType: OCRType
    let selectedRegionID: UUID?
    let drawnRegions: [RegionBox]
    let screenshot: NSImage
    let onParametersChanged: () -> Void
    
    @State private var showColorFiltering = false
    @State private var showAdvancedOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show which OCR type's parameters are being edited
            Text("\(ocrTypeDisplayName()) Parameters")
                .font(.headline)
                .padding(.bottom, 4)
            
            // BASIC PARAMETERS
            VStack(alignment: .leading, spacing: 8) {
                Text("Basic Processing")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ParameterSlider(
                    title: "Scale",
                    value: $parameters.scale,
                    range: 1.0...8.0,
                    step: 0.5,
                    onChange: onParametersChanged
                )
                
                ParameterSlider(
                    title: "Sharpness",
                    value: $parameters.sharpness,
                    range: 0.0...2.0,
                    step: 0.1,
                    onChange: onParametersChanged
                )
                
                ParameterSlider(
                    title: "Contrast",
                    value: $parameters.contrast,
                    range: 0.5...3.0,
                    step: 0.1,
                    onChange: onParametersChanged
                )
                
                ParameterSlider(
                    title: "Brightness",
                    value: $parameters.brightness,
                    range: -1.0...1.0,
                    step: 0.1,
                    onChange: onParametersChanged
                )
                
                ParameterSlider(
                    title: "Blur Radius",
                    value: $parameters.blurRadius,
                    range: 0.0...3.0,
                    step: 0.1,
                    onChange: onParametersChanged
                )
                
                ParameterSlider(
                    title: "Threshold",
                    value: $parameters.threshold,
                    range: 0.0...1.0,
                    step: 0.05,
                    onChange: onParametersChanged
                )
                
                ParameterSlider(
                    title: "Morph Radius",
                    value: $parameters.morphRadius,
                    range: 0.0...3.0,
                    step: 0.1,
                    onChange: onParametersChanged
                )
            }
            
            // COLOR FILTERING SECTION
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Color Filtering")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: {
                        showColorFiltering.toggle()
                    }) {
                        Image(systemName: showColorFiltering ? "chevron.up" : "chevron.down")
                    }
                    .buttonStyle(.plain)
                }
                
                if showColorFiltering {
                    Picker("Filter Mode", selection: $parameters.colorFilterMode) {
                        ForEach(ColorFilterMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: parameters.colorFilterMode) { _ in onParametersChanged() }
                    
                    if parameters.colorFilterMode == .hsvFilter {
                        ParameterSlider(
                            title: "HSV Hue Min",
                            value: $parameters.hsvHueMin,
                            range: 0.0...360.0,
                            step: 5.0,
                            onChange: onParametersChanged
                        )
                        
                        ParameterSlider(
                            title: "HSV Hue Max",
                            value: $parameters.hsvHueMax,
                            range: 0.0...360.0,
                            step: 5.0,
                            onChange: onParametersChanged
                        )
                        
                        ParameterSlider(
                            title: "HSV Sat Min",
                            value: $parameters.hsvSatMin,
                            range: 0.0...1.0,
                            step: 0.05,
                            onChange: onParametersChanged
                        )
                        
                        ParameterSlider(
                            title: "HSV Sat Max",
                            value: $parameters.hsvSatMax,
                            range: 0.0...1.0,
                            step: 0.05,
                            onChange: onParametersChanged
                        )
                    }
                    
                    if parameters.colorFilterMode == .colorDistance {
                        ParameterSlider(
                            title: "Color Distance",
                            value: $parameters.colorDistanceThreshold,
                            range: 0.0...1.0,
                            step: 0.05,
                            onChange: onParametersChanged
                        )
                    }
                    
                    if parameters.colorFilterMode == .whiteIsolation {
                        ParameterSlider(
                            title: "White Brightness",
                            value: $parameters.whiteBrightnessThreshold,
                            range: 0.0...1.0,
                            step: 0.05,
                            onChange: onParametersChanged
                        )
                        
                        ParameterSlider(
                            title: "Max Saturation",
                            value: $parameters.whiteSaturationMax,
                            range: 0.0...1.0,
                            step: 0.05,
                            onChange: onParametersChanged
                        )
                    }
                }
            }
            
            // ADVANCED OPTIONS SECTION
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Advanced Processing")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: {
                        showAdvancedOptions.toggle()
                    }) {
                        Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                    }
                    .buttonStyle(.plain)
                }
                
                if showAdvancedOptions {
                    Toggle("Adaptive Threshold", isOn: $parameters.useAdaptiveThreshold)
                        .onChange(of: parameters.useAdaptiveThreshold) { _ in onParametersChanged() }
                    
                    if parameters.useAdaptiveThreshold {
                        HStack {
                            Text("Block Size")
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)
                            Spacer()
                            Text("\(parameters.adaptiveThresholdBlockSize)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(parameters.adaptiveThresholdBlockSize) },
                            set: { parameters.adaptiveThresholdBlockSize = Int($0) }
                        ), in: 3...21, step: 2) {
                            Text("Block Size")
                        }
                        .onChange(of: parameters.adaptiveThresholdBlockSize) { _ in onParametersChanged() }
                        
                        ParameterSlider(
                            title: "Adaptive C",
                            value: $parameters.adaptiveThresholdC,
                            range: 0.0...10.0,
                            step: 0.5,
                            onChange: onParametersChanged
                        )
                    }
                    
                    Toggle("Background Subtraction", isOn: $parameters.useBackgroundSubtraction)
                        .onChange(of: parameters.useBackgroundSubtraction) { _ in onParametersChanged() }
                    
                    if parameters.useBackgroundSubtraction {
                        ParameterSlider(
                            title: "BG Blur Radius",
                            value: $parameters.backgroundBlurRadius,
                            range: 5.0...50.0,
                            step: 1.0,
                            onChange: onParametersChanged
                        )
                    }
                    
                    Toggle("Bilateral Filter", isOn: $parameters.useBilateralFilter)
                        .onChange(of: parameters.useBilateralFilter) { _ in onParametersChanged() }
                    
                    if parameters.useBilateralFilter {
                        ParameterSlider(
                            title: "Sigma Color",
                            value: $parameters.bilateralSigmaColor,
                            range: 10.0...150.0,
                            step: 5.0,
                            onChange: onParametersChanged
                        )
                        
                        ParameterSlider(
                            title: "Sigma Space",
                            value: $parameters.bilateralSigmaSpace,
                            range: 10.0...150.0,
                            step: 5.0,
                            onChange: onParametersChanged
                        )
                    }
                    
                    Picker("Morphology", selection: $parameters.morphologyMode) {
                        ForEach(MorphologyMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: parameters.morphologyMode) { _ in onParametersChanged() }
                    
                    if parameters.morphologyMode != .none {
                        ParameterSlider(
                            title: "Morph Size",
                            value: $parameters.morphologySize,
                            range: 0.5...5.0,
                            step: 0.1,
                            onChange: onParametersChanged
                        )
                    }
                }
            }
            
            Button("Reset to Defaults") {
                resetToDefaults()
                onParametersChanged()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Functions
    
    private func ocrTypeDisplayName() -> String {
        switch selectedOCRType {
        case .baseOCR:
            return "Base OCR"
        case .playerBet:
            return "Player Bet"
        case .playerBalance:
            return "Player Balance"
        case .playerAction:
            return "Player Action"
        case .tablePot:
            return "Table Pot"
        }
    }
    
    private func resetToDefaults() {
        switch selectedOCRType {
        case .baseOCR:
            parameters = OCRParameters.default
        case .playerBet:
            parameters = OCRParameters(
                scale: 6.0,
                sharpness: 0.4,
                contrast: 1.5,
                brightness: 0.0,
                saturation: 0.0,
                blurRadius: 2.0,
                threshold: 0.55,
                morphRadius: 0.5,
                colorFilterMode: .hsvFilter,
                hsvHueMin: 60.0,
                hsvHueMax: 180.0,
                hsvSatMin: 0.30,
                hsvSatMax: 1.0
            )
        case .playerBalance:
            parameters = OCRParameters(
                scale: 4.0,
                sharpness: 0.40,
                contrast: 1.60,
                brightness: 0.30,
                saturation: 0.0,
                blurRadius: 0.50,
                threshold: 0.20,
                morphRadius: 0.10,
                colorFilterMode: .colorDistance,
                colorDistanceThreshold: 0.40
            )
        case .playerAction:
            parameters = OCRParameters(
                scale: 4.0,
                sharpness: 0.40,
                contrast: 1.40,
                brightness: 0.40,
                saturation: 0.0,
                blurRadius: 0.50,
                threshold: 0.50,
                morphRadius: 0.10,
                colorFilterMode: .colorDistance,
                colorDistanceThreshold: 0.40
            )
        case .tablePot:
            parameters = OCRParameters(
                scale: 4.0,
                sharpness: 0.40,
                contrast: 1.60,
                brightness: 0.30,
                saturation: 0.0,
                blurRadius: 0.50,
                threshold: 0.25,
                morphRadius: 0.10,
                colorFilterMode: .colorDistance,
                colorDistanceThreshold: 0.80
            )
        }
    }
}

struct ParameterSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float
    let onChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .frame(width: 80, alignment: .leading)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range, step: step) {
                Text(title)
            }
            .onChange(of: value) { _ in
                onChange()
            }
        }
    }
}

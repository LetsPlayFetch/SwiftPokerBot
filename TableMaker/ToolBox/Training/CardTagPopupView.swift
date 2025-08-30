import SwiftUI

struct CardTagPopupView: View {
    let onTagSelected: (String) -> Void
    let onCancel: () -> Void
    
    private let actionTags = ["Empty", "Check", "Call", "Raise", "Fold", "Bet", "Post", "Straddle", "All-In", "Blinds", "SittingOut"]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Action Tag")
                .font(.headline)
                .padding(.bottom, 8)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(actionTags, id: \.self) { action in
                    Button(action: {
                        onTagSelected(action)
                    }) {
                        Text(action)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

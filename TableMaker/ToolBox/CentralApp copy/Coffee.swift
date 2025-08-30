import SwiftUI
import ScreenCaptureKit

struct Coffee: View {
    @StateObject private var coffee = PourCoffee()
    @State private var availableWindows: [SCWindow] = []
    @State private var selectedWindow: SCWindow?
    @State private var isStreaming: Bool = false

    var body: some View {
        VStack {
            if let image = coffee.image {
                RegionEditorView(image: image)
            }

            if !isStreaming {
                // Initial state: Show dropdown and Start Stream button
                Picker("Choose a window", selection: $selectedWindow) {
                    ForEach(availableWindows, id: \.self) { win in
                        Text(win.title ?? "Unnamed Window").tag(Optional(win))
                    }
                }

                Button("Start Stream") {
                    Task {
                        if let win = selectedWindow {
                            await coffee.start(window: win)
                            isStreaming = true
                        }
                    }
                }
            } else {
                // Streaming state: Show Refresh and Select New Stream buttons
                HStack(spacing: 16) {
                    Button("Refresh Screen") {
                        Task {
                            do {
                                try await coffee.captureOneFrame()
                            } catch {
                                print("Error refreshing screen: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Select New Stream") {
                        Task {
                            isStreaming = false
                            await refreshWindowList()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .onAppear {
            Task {
                await refreshWindowList()
            }
        }
    }
    
    private func refreshWindowList() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            // Debug: print window list details
            for win in content.windows {
                let pid = win.owningApplication?.processID ?? -1
                print("🔍 SCWindow title='\(win.title ?? "nil")', processID=\(pid), windowID=\(win.windowID), frame=\(win.frame)")
            }
            availableWindows = content.windows
            selectedWindow = nil // Reset selection when refreshing
        } catch {
            print("Failed to load windows: \(error)")
        }
    }
}

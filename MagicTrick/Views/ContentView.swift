import SwiftUI

/// Root view — orientation-driven phase routing, no buttons or labels
struct ContentView: View {
    @StateObject private var viewModel = TrickViewModel()
    @ObservedObject private var motionManager = MotionManager.shared
    @State private var lastLandscapeIsLeft: Bool = false  // true = left landscape, false = right landscape
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { .current(from: colorScheme) }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // Background gradient
                theme.backgroundGradient
                    .ignoresSafeArea()

                // DeckView always present — stacked deck visible underneath during return
                DeckView(viewModel: viewModel, fanFromLeft: lastLandscapeIsLeft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0)

                // Dismiss overlay — tap anywhere to dismiss the revealed card
                if viewModel.revealedCardID != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.dismissReveal() }
                        .zIndex(5)
                }

                // Secret invisible trigger — top right corner, only during shuffling
                if viewModel.phase == .shuffling {
                    Color.clear
                        .frame(width: 80, height: 80)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            viewModel.secretTriggerTapped()
                        }
                        .position(x: geometry.size.width - 40, y: geometry.safeAreaInsets.top + 40)
                        .zIndex(9999)
                }
            }
            .ignoresSafeArea()
            // Handle rotation for phase transitions
            .onChange(of: isLandscape) { newValue in
                if newValue {
                    // Detect rotation direction from device orientation
                    let deviceOrientation = UIDevice.current.orientation
                    if deviceOrientation == .landscapeLeft {
                        // Home button on right → fan from left to right
                        lastLandscapeIsLeft = false
                    } else if deviceOrientation == .landscapeRight {
                        // Home button on left → fan from right to left
                        lastLandscapeIsLeft = true
                    }
                    viewModel.onRotateToLandscape()
                } else {
                    viewModel.onRotateToPortrait()
                }
            }
            .onChange(of: motionManager.isShaking) { shaking in
                if shaking {
                    viewModel.onShakeStart()
                } else {
                    viewModel.onShakeEnd()
                }
            }
            .onAppear {
                MotionManager.shared.startMonitoring()
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            }
            .onDisappear {
                MotionManager.shared.stopMonitoring()
            }
        }
        .statusBarHidden(true)
    }

}

#Preview {
    ContentView()
}

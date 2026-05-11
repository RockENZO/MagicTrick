import SwiftUI

/// Root view — orientation-driven phase routing, no buttons or labels
struct ContentView: View {
    @StateObject private var viewModel = TrickViewModel()
    @ObservedObject private var motionManager = MotionManager.shared
    @State private var lastLandscapeIsLeft: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // Background gradient from color scheme
                LinearGradient(
                    colors: viewModel.colorScheme.backgroundColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // DeckView always present
                DeckView(viewModel: viewModel, fanFromLeft: lastLandscapeIsLeft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0)

                // Reveal card
                if viewModel.phase == .reveal || viewModel.phase == .returning, let card = viewModel.revealCard {
                    RevealView(
                        card: card,
                        returning: viewModel.phase == .returning,
                        onReturnFinished: { viewModel.finishReturn() }
                    )
                    .zIndex(10)
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

                // Color scheme switcher — triple-tap on deck during idle
                if viewModel.phase == .idle {
                    Color.clear
                        .frame(width: 120, height: 120)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 3) {
                            viewModel.cycleColorScheme()
                        }
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .zIndex(9999)
                }

                // Scheme name indicator — briefly shown on switch
                if viewModel.phase == .idle {
                    Text(viewModel.colorScheme.name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .position(x: geometry.size.width / 2, y: geometry.size.height - 60)
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
            .onChange(of: isLandscape) { newValue in
                if newValue {
                    let deviceOrientation = UIDevice.current.orientation
                    if deviceOrientation == .landscapeLeft {
                        lastLandscapeIsLeft = false
                    } else if deviceOrientation == .landscapeRight {
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

import SwiftUI

/// Root view — orientation-driven phase routing, no buttons or labels
struct ContentView: View {
    @StateObject private var viewModel = TrickViewModel()
    @ObservedObject private var motionManager = MotionManager.shared

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // Background gradient
                backgroundGradient

                // Main content — deck or reveal
                if viewModel.phase == .reveal, let card = viewModel.revealCard {
                    RevealView(card: card)
                        .transition(.opacity)
                } else {
                    DeckView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // Handle rotation for phases where DeckView is not visible (.reveal)
            .onChange(of: isLandscape) { newValue in
                if newValue {
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
            }
            .onDisappear {
                MotionManager.shared.stopMonitoring()
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.15),
                Color(red: 0.03, green: 0.05, blue: 0.10),
                Color(red: 0.01, green: 0.02, blue: 0.05),
                .black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}

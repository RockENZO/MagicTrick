import SwiftUI

/// Reveal overlay — card flips face-up with dramatic 3D perspective.
/// On return, performs a single-card shuffle animation: flip face-down → lift →
/// sweep → drop into deck with spring bounce — like a real overhand return.
struct RevealView: View {
    let card: Card
    var returning: Bool = false
    var onReturnFinished: (() -> Void)? = nil

    // Reveal entrance state
    @State private var appeared = false
    @State private var flipAngle: Double = 90
    @State private var revealScale: CGFloat = 0.85
    @State private var revealGlow: Double = 0

    // Return animation state
    @State private var isFaceDown = false
    @State private var returnPhase: ReturnPhase = .idle

    // Card motion (relative to center)
    @State private var cardOffsetY: CGFloat = 0
    @State private var cardOffsetX: CGFloat = 0
    @State private var cardRotation: Double = 0
    @State private var cardScale: CGFloat = 1.0
    @State private var cardOpacity: Double = 1.0
    @State private var overlayOpacity: Double = 0.7
    @State private var labelOpacity: Double = 1.0

    private let revealCardWidth: CGFloat = 140
    private let revealCardHeight: CGFloat = 210
    private let deckRatio: CGFloat = 80.0 / 140.0

    private enum ReturnPhase {
        case idle, flipping, lifting, sweeping, dropping, fading
    }

    var body: some View {
        ZStack {
            // Dark overlay with animated fade
            Color.black.opacity(overlayOpacity)
                .ignoresSafeArea()

            // Ambient glow behind card during reveal
            if returnPhase == .idle && appeared {
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
                .opacity(revealGlow)
                .allowsHitTesting(false)
            }

            // Card positioned freely in center for shuffle motion
            CardView(
                card: card,
                width: revealCardWidth,
                height: revealCardHeight,
                isDragging: false,
                faceUp: !isFaceDown,
                elevation: returnPhase == .idle ? -40 : cardOffsetY
            )
            .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotationEffect(.degrees(cardRotation))
            .offset(x: cardOffsetX, y: cardOffsetY)
            .scaleEffect(cardScale * revealScale)
            .shadow(
                color: .black.opacity(returnPhase == .idle ? 0.5 : 0.2),
                radius: returnPhase == .idle ? 20 : 8,
                x: 0,
                y: returnPhase == .idle ? 10 : 4
            )
            .opacity(cardOpacity)

            // Card name — below card position
            Text(card.fullName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .opacity(labelOpacity)
                .offset(y: 160)
        }
        .onAppear {
            runRevealEntrance()
        }
        .onChange(of: returning) { isReturning in
            guard isReturning else { return }
            runReturnShuffle()
        }
    }

    // MARK: - Reveal Entrance

    private func runRevealEntrance() {
        // Fade overlay in
        withAnimation(.easeOut(duration: 0.35)) {
            appeared = true
            labelOpacity = 1.0
        }

        // Scale up from slightly smaller — creates a "popping out" feel
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            revealScale = 1.0
        }

        // 3D flip — card rotates from edge to face-up
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.15)) {
            flipAngle = 0
        }

        // Glow pulse during flip — fades after
        withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
            revealGlow = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.5)) {
                revealGlow = 0
            }
        }

        // Subtle haptic on flip landing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HapticManager.shared.cardFlip()
        }
    }

    // MARK: - Single-Card Shuffle Return

    private func runReturnShuffle() {
        // Hide label immediately
        withAnimation(.easeOut(duration: 0.15)) {
            labelOpacity = 0
            revealGlow = 0
        }

        // --- Phase 1: Flip face-down (two-stage rotation) ---
        returnPhase = .flipping
        // Stage 1: rotate to edge (card vanishes)
        withAnimation(.easeIn(duration: 0.2)) {
            flipAngle = 90
        }
        // Stage 2: swap face and complete rotation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isFaceDown = true
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                flipAngle = 0
            }
            HapticManager.shared.cardFlip()
        }

        // --- Phase 2: Lift (pick up from table) ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            returnPhase = .lifting
            HapticManager.shared.shuffle()
            // Natural lift — slightly off-center, tilted like held between fingers
            withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) {
                cardOffsetY = -180
                cardRotation = -5
                cardOffsetX = -12
            }
        }

        // --- Phase 3: Sweep right (draw across the deck) ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            returnPhase = .sweeping
            // Smooth arc motion — like sliding a card across felt
            withAnimation(.easeInOut(duration: 0.25)) {
                cardOffsetX = 45
                cardOffsetY = -120
                cardRotation = 3.5
            }
        }

        // --- Phase 4: Drop into stack with spring bounce ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            returnPhase = .dropping
            HapticManager.shared.shuffle()
            // Drop with physics — overshoot then settle
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                cardOffsetY = 8       // slight overshoot below center
                cardOffsetX = 0
                cardRotation = 0.5    // tiny residual tilt
                cardScale = deckRatio
            }
            // Settle overshoot
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.65)) {
                    cardOffsetY = 0
                    cardRotation = 0
                }
            }
            // Fade overlay as card lands
            withAnimation(.easeOut(duration: 0.35)) {
                overlayOpacity = 0
            }
        }

        // --- Phase 5: Fade card out (deck visible underneath) ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            returnPhase = .fading
            withAnimation(.easeOut(duration: 0.2)) {
                cardOpacity = 0
            }
        }

        // --- Cleanup ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            onReturnFinished?()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RevealView(card: Card(rank: .ace, suit: .spades))
    }
}

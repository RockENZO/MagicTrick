import SwiftUI

/// Reveal overlay — card flips face-up with dramatic 3D perspective.
/// On return, performs a single-card shuffle animation: flip face-down → lift →
/// sweep → drop into deck with spring bounce — like a real overhand return.
/// 3D effects are used here (single card) but NOT in DeckView (52 cards).
struct RevealView: View {
    let card: Card
    var returning: Bool = false
    var onReturnFinished: (() -> Void)? = nil

    // Reveal entrance state
    @State private var appeared = false
    @State private var flipAngle: Double = 90
    @State private var revealScale: CGFloat = 0.85

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
            // Dark overlay
            Color.black.opacity(overlayOpacity)
                .ignoresSafeArea()

            // Card with 3D flip — perspective is fine here (single card)
            CardView(
                card: card,
                width: revealCardWidth,
                height: revealCardHeight,
                isDragging: false,
                faceUp: !isFaceDown
            )
            .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotationEffect(.degrees(cardRotation))
            .offset(x: cardOffsetX, y: cardOffsetY)
            .scaleEffect(cardScale * revealScale)
            .shadow(
                color: .black.opacity(returnPhase == .idle ? 0.45 : 0.2),
                radius: returnPhase == .idle ? 16 : 6,
                x: 0,
                y: returnPhase == .idle ? 8 : 3
            )
            .opacity(cardOpacity)

            // Card name
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
        withAnimation(.easeOut(duration: 0.35)) {
            appeared = true
            labelOpacity = 1.0
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            revealScale = 1.0
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.15)) {
            flipAngle = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HapticManager.shared.cardFlip()
        }
    }

    // MARK: - Single-Card Shuffle Return

    private func runReturnShuffle() {
        withAnimation(.easeOut(duration: 0.15)) {
            labelOpacity = 0
        }

        // --- Phase 1: Flip face-down ---
        returnPhase = .flipping
        withAnimation(.easeIn(duration: 0.2)) {
            flipAngle = 90
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isFaceDown = true
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                flipAngle = 0
            }
            HapticManager.shared.cardFlip()
        }

        // --- Phase 2: Lift ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            returnPhase = .lifting
            HapticManager.shared.shuffle()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) {
                cardOffsetY = -180
                cardRotation = -5
                cardOffsetX = -12
            }
        }

        // --- Phase 3: Sweep right ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            returnPhase = .sweeping
            withAnimation(.easeInOut(duration: 0.25)) {
                cardOffsetX = 45
                cardOffsetY = -120
                cardRotation = 3.5
            }
        }

        // --- Phase 4: Drop with spring bounce ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            returnPhase = .dropping
            HapticManager.shared.shuffle()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                cardOffsetY = 8
                cardOffsetX = 0
                cardRotation = 0.5
                cardScale = deckRatio
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.65)) {
                    cardOffsetY = 0
                    cardRotation = 0
                }
            }
            withAnimation(.easeOut(duration: 0.35)) {
                overlayOpacity = 0
            }
        }

        // --- Phase 5: Fade out ---
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

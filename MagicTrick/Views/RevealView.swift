import SwiftUI

/// Reveal overlay — card flips face-up. On return, performs a single-card shuffle
/// animation: flip face-down → lift → sweep → drop into deck with spring bounce.
struct RevealView: View {
    let card: Card
    var returning: Bool = false
    var onReturnFinished: (() -> Void)? = nil

    // Reveal entrance state
    @State private var appeared = false
    @State private var flipAngle: Double = 90

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

            // Card positioned freely in center for shuffle motion
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
            .scaleEffect(cardScale)
            .shadow(color: .black.opacity(returnPhase == .idle ? 0.5 : 0.2), radius: returnPhase == .idle ? 20 : 8, x: 0, y: returnPhase == .idle ? 10 : 4)
            .opacity(cardOpacity)

            // Card name — below card position
            Text(card.fullName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .opacity(labelOpacity)
                .offset(y: 160)
        }
        .onAppear {
            // Reveal entrance: card flips face-up
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
                labelOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                flipAngle = 0
            }
        }
        .onChange(of: returning) { isReturning in
            guard isReturning else { return }
            runReturnShuffle()
        }
    }

    // MARK: - Single-Card Shuffle Return

    private func runReturnShuffle() {
        // Hide label immediately
        withAnimation(.easeOut(duration: 0.15)) {
            labelOpacity = 0
        }

        // --- Phase 1: Flip face-down ---
        returnPhase = .flipping
        withAnimation(.easeIn(duration: 0.22)) {
            flipAngle = 90   // edge — card vanishes
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isFaceDown = true
            withAnimation(.easeOut(duration: 0.22)) {
                flipAngle = 0  // complete flip
            }
        }

        // --- Phase 2: Lift up (like picking up in overhand shuffle) ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            returnPhase = .lifting
            HapticManager.shared.shuffle()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                cardOffsetY = -200       // lift high
                cardRotation = -6        // slight tilt (held angle)
                cardOffsetX = -15        // slight left lean
            }
        }

        // --- Phase 3: Sweep right (draw across the deck) ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            returnPhase = .sweeping
            withAnimation(.easeInOut(duration: 0.22)) {
                cardOffsetX = 50         // sweep right
                cardOffsetY = -140       // lower slightly
                cardRotation = 4         // tilt other way
            }
        }

        // --- Phase 4: Drop into stack with spring bounce ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.98) {
            returnPhase = .dropping
            HapticManager.shared.shuffle()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                cardOffsetY = 0          // drop to center (deck position)
                cardOffsetX = 0          // snap to center
                cardRotation = 0         // straighten
                cardScale = deckRatio    // shrink to deck card size
            }
            // Fade overlay as card lands
            withAnimation(.easeOut(duration: 0.3)) {
                overlayOpacity = 0
            }
        }

        // --- Phase 5: Fade card out (deck visible underneath) ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            returnPhase = .fading
            withAnimation(.easeOut(duration: 0.2)) {
                cardOpacity = 0
            }
        }

        // --- Cleanup ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
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

import SwiftUI

/// Unified card layout — same card views animate between phases:
/// - idle: stacked (portrait)
/// - spread: fanned across screen width (landscape), per-card drag-up with finger tracking
/// - reveal: same as spread (so we can animate the tapped card)
/// - shuffling: riffle animation on the centered stack
struct DeckView: View {
    @ObservedObject var viewModel: TrickViewModel

    private let cardWidth: CGFloat = 80
    private let cardHeight: CGFloat = 120

    // Animated screen-size interpolation for smooth rotation transitions
    @State private var animatedScreenSize: CGSize = .zero
    @State private var targetScreenSize: CGSize = .zero
    @State private var hasAppeared = false

    var body: some View {
        GeometryReader { geometry in
            // Use animated screen size for smooth rotation interpolation
            let screenW = animatedScreenSize.width > 0 ? animatedScreenSize.width : geometry.size.width
            let screenH = animatedScreenSize.height > 0 ? animatedScreenSize.height : geometry.size.height
            let centerX = screenW / 2
            let centerY = screenH / 2

            ZStack {
                ForEach(Array(viewModel.deck.enumerated()), id: \.element.id) { index, card in
                    let layout = cardLayout(
                        index: index,
                        total: viewModel.deck.count,
                        screenW: screenW,
                        screenH: screenH,
                        centerX: centerX,
                        centerY: centerY
                    )

                    let isPeeked = viewModel.peekedCardID == card.id
                    let isFaceUp = card.isFaceUp

                    // Shuffle offsets for this card (0 when not shuffling)
                    let shuffleY: CGFloat = (index < viewModel.shuffleOffsets.count)
                        ? viewModel.shuffleOffsets[index]
                        : 0
                    let shuffleX: CGFloat = (index < viewModel.shuffleLateral.count)
                        ? viewModel.shuffleLateral[index]
                        : 0

                    // Shuffle rotation — cards flutter while airborne
                    let shuffleRotation: Double = shuffleY != 0
                        ? Double(index % 5 - 2) * 2.5
                        : 0

                    CardView(
                        card: card,
                        width: cardWidth,
                        height: cardHeight,
                        isDragging: isPeeked,
                        faceUp: isFaceUp
                    )
                    .position(
                        x: layout.x + shuffleX + (isPeeked ? viewModel.peekOffset.width : 0),
                        y: layout.y + (isPeeked ? viewModel.peekOffset.height : 0) + shuffleY
                    )
                    .rotationEffect(.degrees(layout.rotation + shuffleRotation + (isPeeked ? peekRotation : 0)), anchor: .center)
                    .scaleEffect(isPeeked ? 1.08 : layout.scale)
                    .zIndex(isPeeked ? 1000 : layout.zIndex)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard viewModel.phase == .spread else { return }

                                // Start tracking this card on first touch
                                if viewModel.peekedCardID == nil {
                                    viewModel.beginPeek(id: card.id)
                                }

                                // Update drag offset — before flip: Y only, after: full 2D
                                if viewModel.peekedCardID == card.id {
                                    viewModel.updatePeekOffset(to: value.translation)
                                }
                            }
                            .onEnded { _ in
                                guard viewModel.phase == .spread else { return }
                                if viewModel.peekedCardID == card.id {
                                    viewModel.releasePeek(at: index)
                                }
                            }
                    )
                    .allowsHitTesting(
                        viewModel.phase == .spread
                            ? (isPeeked || viewModel.peekedCardID == nil)
                            : false
                    )
                }
            }
            // Detect geometry changes for smooth rotation interpolation
            .onAppear {
                guard !hasAppeared else { return }
                animatedScreenSize = geometry.size
                targetScreenSize = geometry.size
                hasAppeared = true
            }
            .onChange(of: geometry.size) { newSize in
                guard hasAppeared else { return }
                guard newSize.width > 0 && newSize.height > 0 else { return }

                let dx = newSize.width - targetScreenSize.width
                let dy = newSize.height - targetScreenSize.height
                let distance = sqrt(dx * dx + dy * dy)

                if distance > 1 {
                    // Meaningful size change (rotation) — spring-animate the screen size
                    targetScreenSize = newSize

                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        animatedScreenSize = newSize
                    }

                    // Trigger instant phase change
                    if newSize.width > newSize.height {
                        viewModel.onRotateToLandscape()
                    } else {
                        viewModel.onRotateToPortrait()
                    }
                } else {
                    // Negligible change (safe area inset, etc.) — snap
                    targetScreenSize = newSize
                    animatedScreenSize = newSize
                }
            }
        }
    }

    // MARK: - Peek Rotation (physics-based tilt from drag)

    /// Card rotates slightly based on drag offset — feels like lifting a real card
    private var peekRotation: Double {
        let dx = viewModel.peekOffset.width
        return Double(dx) * 0.05
    }

    // MARK: - Card Layout (absolute screen positions)

    private struct CardPosition {
        let x: CGFloat
        let y: CGFloat
        let rotation: Double
        let scale: CGFloat
        let zIndex: Double
    }

    private func cardLayout(
        index: Int,
        total: Int,
        screenW: CGFloat,
        screenH: CGFloat,
        centerX: CGFloat,
        centerY: CGFloat
    ) -> CardPosition {
        switch viewModel.phase {
        case .idle, .returning:
            // Stacked deck — dead center, slight offset per card for depth feel
            let stackX = centerX + CGFloat(index) * 0.3 - CGFloat(total) * 0.15
            let stackY = centerY + CGFloat(index) * 0.5 - CGFloat(total) * 0.25
            return CardPosition(x: stackX, y: stackY, rotation: 0, scale: 1.0, zIndex: Double(index))

        case .shuffling:
            // Wider stack during shuffle — cards spread across screen for dramatic lift
            let stackX = centerX + CGFloat(index) * 2.0 - CGFloat(total) * 1.0
            let stackY = centerY + CGFloat(index) * 2.5 - CGFloat(total) * 1.25
            return CardPosition(x: stackX, y: stackY, rotation: 0, scale: 1.0, zIndex: Double(index))

        case .spread, .reveal:
            // Fan spread — inset from edges to avoid Dynamic Island / safe area
            let margin: CGFloat = cardWidth * 0.6
            let usableWidth = screenW - cardWidth - margin * 2
            let spacing: CGFloat
            if total > 1 {
                spacing = usableWidth / CGFloat(total - 1)
            } else {
                spacing = 0
            }
            let x = margin + (cardWidth / 2) + CGFloat(index) * spacing

            // Natural fan arc — cards in the middle are higher, edges droop
            let normalizedPos = total > 1
                ? (CGFloat(index) / CGFloat(total - 1)) * 2 - 1  // -1 to 1
                : 0
            let arcCurve = normalizedPos * normalizedPos  // Parabolic arc
            let yOffset = arcCurve * 25  // Edges curve down 25pt

            // Fan rotation — each card angles slightly, like a real hand of cards
            let rotation = normalizedPos * 8  // max ±8 degrees

            // Perspective depth — edge cards very slightly smaller (subtle foreshortening)
            let edgeScale = 1.0 - abs(normalizedPos) * 0.015

            return CardPosition(
                x: x,
                y: centerY + yOffset,
                rotation: rotation,
                scale: edgeScale,
                zIndex: Double(index)
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        DeckView(viewModel: TrickViewModel())
    }
}

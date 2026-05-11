import SwiftUI

/// Unified card layout — single parent gesture with hit-testing for natural
/// finger-browse across the fan. Cards tilt + lift on hover, then get
/// dragged out on swipe-up (peek).
struct DeckView: View {
    @ObservedObject var viewModel: TrickViewModel

    private let cardWidth: CGFloat = 80
    private let cardHeight: CGFloat = 120

    // Animated screen-size interpolation for smooth rotation transitions
    @State private var animatedScreenSize: CGSize = .zero
    @State private var targetScreenSize: CGSize = .zero
    @State private var hasAppeared = false

    // Gesture state
    @State private var touchStartY: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
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
                    let isHovered = viewModel.hoveredCardID == card.id
                    let isFaceUp = card.isFaceUp

                    // Shuffle offsets (0 when not shuffling)
                    let shuffleY: CGFloat = (index < viewModel.shuffleOffsets.count)
                        ? viewModel.shuffleOffsets[index] : 0
                    let shuffleX: CGFloat = (index < viewModel.shuffleLateral.count)
                        ? viewModel.shuffleLateral[index] : 0

                    // Shuffle flutter
                    let shuffleRotation: Double = shuffleY != 0
                        ? Double(index % 5 - 2) * 2.5 : 0

                    // Hover: subtle tilt + lift (subdued version of peek)
                    let hoverOffset: CGFloat = isHovered ? -8 : 0
                    let hoverRotation: Double = isHovered ? 3.5 : 0
                    let hoverScale: CGFloat = isHovered ? 1.04 : 1.0

                    CardView(
                        card: card,
                        width: cardWidth,
                        height: cardHeight,
                        isDragging: isPeeked,
                        faceUp: isFaceUp,
                        isHovered: isHovered
                    )
                    .position(
                        x: layout.x + shuffleX + (isPeeked ? viewModel.peekOffset.width : 0),
                        y: layout.y + shuffleY + (isPeeked ? viewModel.peekOffset.height : 0) + hoverOffset
                    )
                    .rotationEffect(
                        .degrees(layout.rotation + shuffleRotation + hoverRotation + (isPeeked ? peekRotation : 0)),
                        anchor: .center
                    )
                    .scaleEffect(isPeeked ? 1.08 : (isHovered ? hoverScale : layout.scale))
                    .zIndex(isPeeked ? 1000 : (isHovered ? 999 : layout.zIndex))
                    .allowsHitTesting(false)  // Parent gesture handles all input
                }
            }
            .frame(width: screenW, height: screenH)  // Explicit frame for gesture area
            .contentShape(Rectangle())  // Ensure gesture area matches frame
            // Single parent gesture — handles both hover browsing and peek dragging
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard viewModel.phase == .spread else { return }
                        let location = value.location

                        if viewModel.peekedCardID == nil {
                            // --- HOVER MODE: finger is browsing the fan ---

                            // Record Y at first touch
                            if viewModel.hoveredCardID == nil {
                                touchStartY = location.y
                            }

                            // Hit-test: which card is under the finger?
                            if let cardIndex = hitTestCard(
                                x: location.x,
                                screenW: screenW,
                                centerX: centerX,
                                total: viewModel.deck.count
                            ) {
                                let cardID = viewModel.deck[cardIndex].id

                                if viewModel.hoveredCardID != cardID {
                                    // Finger moved to a new card — switch hover
                                    viewModel.updateHover(to: cardID)
                                }

                                // Check for swipe-up: finger moved upward past threshold
                                let upwardDelta = touchStartY - location.y
                                if upwardDelta > 40 {
                                    // Transition from hover → peek
                                    viewModel.beginPeek(id: cardID, touchLocation: location)
                                }
                            } else {
                                // Finger is between cards or outside fan — clear hover
                                viewModel.endHover()
                            }
                        } else {
                            // --- PEEK MODE: card is being dragged out ---
                            viewModel.updatePeekOffset(currentLocation: location)
                        }
                    }
                    .onEnded { _ in
                        guard viewModel.phase == .spread else { return }

                        if viewModel.peekedCardID != nil {
                            // Release peeked card
                            if let idx = viewModel.deck.firstIndex(where: { $0.id == viewModel.peekedCardID }) {
                                viewModel.releasePeek(at: idx)
                            }
                        } else {
                            // Clear hover on finger lift
                            viewModel.endHover()
                        }
                    }
            )
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
                    targetScreenSize = newSize
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        animatedScreenSize = newSize
                    }
                    if newSize.width > newSize.height {
                        viewModel.onRotateToLandscape()
                    } else {
                        viewModel.onRotateToPortrait()
                    }
                } else {
                    targetScreenSize = newSize
                    animatedScreenSize = newSize
                }
            }
        }
    }

    // MARK: - Hit Testing

    /// Maps a touch X position to the card index in the fanned layout.
    /// Returns nil if the touch is outside the fan area.
    private func hitTestCard(x: CGFloat, screenW: CGFloat, centerX: CGFloat, total: Int) -> Int? {
        let margin: CGFloat = cardWidth * 0.6
        let fanLeft = margin
        let fanRight = screenW - margin

        guard x >= fanLeft - cardWidth * 0.3 && x <= fanRight + cardWidth * 0.3 else {
            return nil
        }

        // Map X position linearly to card index
        let normalizedX = (x - fanLeft) / max(fanRight - fanLeft, 1)
        let index = Int(round(normalizedX * CGFloat(total - 1)))
        return index.clamped(to: 0...(total - 1))
    }

    // MARK: - Peek Rotation

    private var peekRotation: Double {
        return Double(viewModel.peekOffset.width) * 0.05
    }

    // MARK: - Card Layout

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
            let stackX = centerX + CGFloat(index) * 0.3 - CGFloat(total) * 0.15
            let stackY = centerY + CGFloat(index) * 0.5 - CGFloat(total) * 0.25
            return CardPosition(x: stackX, y: stackY, rotation: 0, scale: 1.0, zIndex: Double(index))

        case .shuffling:
            let stackX = centerX + CGFloat(index) * 2.0 - CGFloat(total) * 1.0
            let stackY = centerY + CGFloat(index) * 2.5 - CGFloat(total) * 1.25
            return CardPosition(x: stackX, y: stackY, rotation: 0, scale: 1.0, zIndex: Double(index))

        case .spread, .reveal:
            let margin: CGFloat = cardWidth * 0.6
            let usableWidth = screenW - cardWidth - margin * 2
            let spacing = total > 1 ? usableWidth / CGFloat(total - 1) : 0
            let x = margin + (cardWidth / 2) + CGFloat(index) * spacing

            let normalizedPos = total > 1
                ? (CGFloat(index) / CGFloat(total - 1)) * 2 - 1
                : 0
            let arcCurve = normalizedPos * normalizedPos
            let yOffset = arcCurve * 25
            let rotation = normalizedPos * 8
            let edgeScale = 1.0 - abs(normalizedPos) * 0.015

            return CardPosition(
                x: x, y: centerY + yOffset,
                rotation: rotation, scale: edgeScale,
                zIndex: Double(index)
            )
        }
    }
}

// MARK: - Comparable Clamped Helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        DeckView(viewModel: TrickViewModel())
    }
}

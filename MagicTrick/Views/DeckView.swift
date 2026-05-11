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

    // Staggered fan-out animation — cards fan one by one from left to right
    @State private var fanProgress: CGFloat = 0  // 0 = stacked, 1 = fully fanned

    // Gesture state
    @State private var touchStartY: CGFloat = 0
    @State private var touchStartX: CGFloat = 0
    @State private var hoverEntryCardID: UUID? = nil  // Card that was hovered when touchStartY was set

    var body: some View {
        GeometryReader { geometry in
            let screenW = animatedScreenSize.width > 0 ? animatedScreenSize.width : geometry.size.width
            let screenH = animatedScreenSize.height > 0 ? animatedScreenSize.height : geometry.size.height
            let centerX = screenW / 2
            let centerY = screenH / 2

            ZStack {
                ForEach(0..<viewModel.deck.count, id: \.self) { index in
                    cardView(at: index, screenW: screenW, screenH: screenH, centerX: centerX, centerY: centerY)
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

                            // Hit-test: which card is under the finger?
                            if let cardIndex = hitTestCard(
                                x: location.x,
                                screenW: screenW,
                                centerX: centerX,
                                total: viewModel.deck.count
                            ) {
                                let cardID = viewModel.deck[cardIndex].id

                                if viewModel.hoveredCardID != cardID {
                                    // Finger moved to a new card — reset swipe tracking for this card
                                    viewModel.updateHover(to: cardID)
                                    touchStartY = location.y
                                    touchStartX = location.x
                                    hoverEntryCardID = cardID
                                }

                                // Record start on first touch
                                if hoverEntryCardID == nil {
                                    touchStartY = location.y
                                    touchStartX = location.x
                                    hoverEntryCardID = cardID
                                }

                                // Check for deliberate swipe-up on THIS card:
                                // - Upward delta from where finger entered this card
                                // - Must be mostly vertical (not a horizontal swipe)
                                let upwardDelta = touchStartY - location.y
                                let horizontalDelta = abs(location.x - touchStartX)
                                let isDeliberateSwipeUp = upwardDelta > 25 && upwardDelta > horizontalDelta * 1.2

                                if isDeliberateSwipeUp {
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
                        hoverEntryCardID = nil
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
                        // Staggered fan-out animation
                        withAnimation(.easeOut(duration: 0.8)) {
                            fanProgress = 1
                        }
                    } else {
                        hoverEntryCardID = nil
                        fanProgress = 0  // Reset instantly for next fan-out
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

    // MARK: - Card View Builder

    private struct HoverValues {
        var offset: CGFloat = 0
        var rotation: Double = 0
        var scale: CGFloat = 1.0
        var shiftX: CGFloat = 0
    }

    private func hoverValues(for index: Int, isHovered: Bool) -> HoverValues {
        let deckCount: Int = viewModel.deck.count
        let normPos: CGFloat = deckCount > 1
            ? (CGFloat(index) / CGFloat(deckCount - 1)) * 2 - 1
            : 0

        let hoveredIdx: Int? = viewModel.hoveredCardID.flatMap { hid in
            viewModel.deck.firstIndex(where: { $0.id == hid })
        }
        let dist: Int = hoveredIdx.map { abs(index - $0) } ?? 99

        var result = HoverValues()

        if isHovered {
            result.offset = -14
            result.rotation = Double(-normPos) * 5.0
            result.scale = 1.07
        } else if dist == 1, let hIdx = hoveredIdx {
            let dir: CGFloat = index > hIdx ? 1.0 : -1.0
            result.offset = 2
            result.rotation = Double(dir) * 2.0
            result.scale = 0.98
            result.shiftX = dir * 6
        } else if dist == 2, let hIdx = hoveredIdx {
            let dir: CGFloat = index > hIdx ? 1.0 : -1.0
            result.offset = 1
            result.rotation = Double(dir) * 0.8
            result.scale = 0.99
            result.shiftX = dir * 2.5
        }

        return result
    }

    @ViewBuilder
    private func cardView(at index: Int, screenW: CGFloat, screenH: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        let card = viewModel.deck[index]
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

        let shuffleY: CGFloat = (index < viewModel.shuffleOffsets.count)
            ? viewModel.shuffleOffsets[index] : 0
        let shuffleX: CGFloat = (index < viewModel.shuffleLateral.count)
            ? viewModel.shuffleLateral[index] : 0

        let flutterBase: Int = index % 5 - 2
        let shuffleRot: Double = shuffleY != 0 ? Double(flutterBase) * 2.5 : 0

        let hv = hoverValues(for: index, isHovered: isHovered)

        let peekDX: CGFloat = isPeeked ? viewModel.peekOffset.width : 0
        let peekDY: CGFloat = isPeeked ? viewModel.peekOffset.height : 0
        let fx: CGFloat = layout.x + shuffleX + hv.shiftX + peekDX
        let fy: CGFloat = layout.y + shuffleY + hv.offset + peekDY
        let fr: Double = layout.rotation + shuffleRot + hv.rotation + (isPeeked ? peekRotation : 0)
        let fs: CGFloat = isPeeked ? 1.08 : (isHovered ? hv.scale : layout.scale)
        let fz: Double = isPeeked ? 1000 : (isHovered ? 999 : layout.zIndex)

        CardView(
            card: card,
            width: cardWidth,
            height: cardHeight,
            isDragging: isPeeked,
            faceUp: isFaceUp,
            isHovered: isHovered
        )
        .position(x: fx, y: fy)
        .rotationEffect(.degrees(fr), anchor: .center)
        .scaleEffect(fs)
        .zIndex(fz)
        .allowsHitTesting(false)
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
            // Stacked position (same as idle)
            let stackX = centerX + CGFloat(index) * 0.3 - CGFloat(total) * 0.15
            let stackY = centerY + CGFloat(index) * 0.5 - CGFloat(total) * 0.25

            // Fanned position
            let margin: CGFloat = cardWidth * 0.6
            let usableWidth = screenW - cardWidth - margin * 2
            let spacing = total > 1 ? usableWidth / CGFloat(total - 1) : 0
            let fanX = margin + (cardWidth / 2) + CGFloat(index) * spacing

            let normalizedPos = total > 1
                ? (CGFloat(index) / CGFloat(total - 1)) * 2 - 1
                : 0
            let arcCurve = normalizedPos * normalizedPos
            let fanYOffset = arcCurve * 25
            let fanRotation = normalizedPos * 8
            let edgeScale = 1.0 - abs(normalizedPos) * 0.015

            // Per-card stagger: each card's fan progress is delayed by its index
            // Card 0 fans first, card 51 fans last
            let staggerDelay = CGFloat(index) / CGFloat(max(total - 1, 1))
            // Card's individual progress: 0 at its start time, 1 at its end time
            // The stagger window is 60% of total duration, rest is for the last cards to catch up
            let staggerWindow: CGFloat = 0.6
            let cardProgress: CGFloat
            if fanProgress <= 0 {
                cardProgress = 0
            } else if fanProgress >= 1 {
                cardProgress = 1
            } else {
                let cardStart = staggerDelay * staggerWindow
                let cardDuration = 1.0 - staggerWindow + staggerWindow * (1.0 - staggerDelay)
                cardProgress = min(max((fanProgress - cardStart) / cardDuration, 0), 1)
            }

            // Ease-out curve for natural deceleration
            let eased = 1.0 - pow(1.0 - cardProgress, 2.5)

            // Interpolate between stacked and fanned
            let finalX = stackX + (fanX - stackX) * eased
            let finalY = stackY + (centerY + fanYOffset - stackY) * eased
            let finalRotation = fanRotation * eased
            let finalScale = 1.0 + (edgeScale - 1.0) * eased

            return CardPosition(
                x: finalX, y: finalY,
                rotation: finalRotation, scale: finalScale,
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

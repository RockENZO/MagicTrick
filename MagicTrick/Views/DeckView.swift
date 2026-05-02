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

    var body: some View {
        GeometryReader { geometry in
            let screenW = geometry.size.width
            let screenH = geometry.size.height
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

                    // Shuffle rotation — cards flutter slightly while airborne
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
                    .rotationEffect(.degrees(layout.rotation + shuffleRotation), anchor: .center)
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
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.phase)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPeeked)
                }
            }
        }
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
        case .idle:
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
            // Slight arc — cards in the middle are higher
            let normalizedPos = total > 1
                ? (CGFloat(index) / CGFloat(total - 1)) * 2 - 1  // -1 to 1
                : 0
            let yOffset = abs(normalizedPos) * 20  // Arc: edges curve down
            // Gentle rotation for fan effect
            let rotation = normalizedPos * 8  // max ±8 degrees
            return CardPosition(
                x: x,
                y: centerY + yOffset,
                rotation: rotation,
                scale: 1.0,
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

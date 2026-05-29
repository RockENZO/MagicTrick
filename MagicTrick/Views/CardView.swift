import SwiftUI

/// A single playing card with face-up/face-down states.
/// Optimized for rendering 52 cards simultaneously — expensive effects
/// (3D perspective, dynamic shadows) are reserved for the peeked card only.
struct CardView: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat
    let isDragging: Bool
    let faceUp: Bool
    var isHovered: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { .current(from: colorScheme) }
    private var cornerRadius: CGFloat { width * 0.08 }

    var body: some View {
        ZStack {
            // Card back (visible when face-down)
            cardBack
                .opacity(faceUp ? 0 : 1)

            // Card face (visible when face-up)
            cardFace
                .opacity(faceUp ? 1 : 0)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    faceUp
                        ? Color.white.opacity(theme.cardFace.borderOpacity)
                        : theme.cardBack.borderColor.opacity(theme.cardBack.borderOpacity * 0.6),
                    lineWidth: 0.5
                )
        )
        // Shadow — resting < hovered < dragging
        .shadow(
            color: .black.opacity(isDragging ? 0.55 : (isHovered ? 0.4 : 0.3)),
            radius: isDragging ? 12 : (isHovered ? 7 : 4),
            x: 0,
            y: isDragging ? 8 : (isHovered ? 4 : 2)
        )
    }

    // MARK: - Card Back

    private var cardBack: some View {
        let style = theme.cardBack

        return ZStack {
            // Solid fill
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(style.fill)

            // Sheen highlight from top-left (dark mode only)
            if style.sheenOpacity > 0 {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(style.sheenOpacity),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Thin inner border
            RoundedRectangle(cornerRadius: cornerRadius - 2)
                .strokeBorder(style.borderColor.opacity(style.borderOpacity), lineWidth: 0.5)
                .padding(4)

            // Centered diamond outline
            CardDiamond()
                .stroke(style.monogramColor.opacity(style.monogramOpacity), lineWidth: style.monogramLineWidth)
                .frame(width: 16, height: 16)

            // Four corner dots
            cornerDot(x: 9, y: 9, style: style)
            cornerDot(x: width - 9, y: 9, style: style)
            cornerDot(x: 9, y: height - 9, style: style)
            cornerDot(x: width - 9, y: height - 9, style: style)
        }
    }

    private func cornerDot(x: CGFloat, y: CGFloat, style: AppTheme.CardBackStyle) -> some View {
        Circle()
            .fill(style.dotColor.opacity(style.dotOpacity))
            .frame(width: 2.5, height: 2.5)
            .position(x: x, y: y)
    }

    // MARK: - Card Face

    private var cardFace: some View {
        ZStack {
            // Cream white background
            theme.cardFace.fill

            // Top-left pip
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    VStack(spacing: 1) {
                        Text(card.rank.displaySymbol)
                            .font(.system(size: width * 0.26, weight: .bold, design: .serif))
                            .foregroundColor(card.suit.color)
                        Text(card.suit.rawValue)
                            .font(.system(size: width * 0.2))
                            .foregroundColor(card.suit.color)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(width * 0.09)

            // Center watermark
            ZStack {
                Text(card.suit.rawValue)
                    .font(.system(size: width * 0.45))
                    .foregroundColor(card.suit.color.opacity(0.12))
                Text(card.rank.displaySymbol)
                    .font(.system(size: width * 0.55, weight: .heavy, design: .serif))
                    .foregroundColor(card.suit.color.opacity(0.06))
            }

            // Bottom-right pip (inverted)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 1) {
                        Text(card.suit.rawValue)
                            .font(.system(size: width * 0.2))
                            .foregroundColor(card.suit.color)
                            .rotationEffect(.degrees(180))
                        Text(card.rank.displaySymbol)
                            .font(.system(size: width * 0.26, weight: .bold, design: .serif))
                            .foregroundColor(card.suit.color)
                            .rotationEffect(.degrees(180))
                    }
                }
            }
            .padding(width * 0.09)
        }
    }
}

// MARK: - Diamond Shape
private struct CardDiamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 20) {
            CardView(
                card: Card(rank: .ace, suit: .spades),
                width: 100, height: 150,
                isDragging: false, faceUp: false
            )
            CardView(
                card: Card(rank: .queen, suit: .hearts),
                width: 100, height: 150,
                isDragging: false, faceUp: true
            )
            CardView(
                card: Card(rank: .ten, suit: .diamonds),
                width: 100, height: 150,
                isDragging: true, faceUp: true
            )
        }
    }
}

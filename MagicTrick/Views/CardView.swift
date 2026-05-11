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
    var colorScheme: CardColorScheme = .midnight

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
                .stroke(Color.white.opacity(faceUp ? 0.05 : 0.12), lineWidth: 0.5)
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
        ZStack {
            // Base color from scheme
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(colorScheme.cardBackBase)

            // Sheen highlight from top-left
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme.cardBackSheenOpacity),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Thin inner border
            RoundedRectangle(cornerRadius: cornerRadius - 2)
                .strokeBorder(Color.white.opacity(colorScheme.cardBorderOpacity), lineWidth: 0.5)
                .padding(4)

            // Centered diamond outline
            CardDiamond()
                .stroke(Color.white.opacity(colorScheme.cardDiamondOpacity), lineWidth: 0.8)
                .frame(width: 16, height: 16)

            // Four corner dots
            cornerDot(x: 9, y: 9)
            cornerDot(x: width - 9, y: 9)
            cornerDot(x: 9, y: height - 9)
            cornerDot(x: width - 9, y: height - 9)
        }
    }

    private func cornerDot(x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(Color.white.opacity(colorScheme.cornerDotOpacity))
            .frame(width: 2.5, height: 2.5)
            .position(x: x, y: y)
    }

    // MARK: - Card Face

    private var cardFace: some View {
        ZStack {
            // Paper background from scheme
            colorScheme.cardFaceBackground

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
            ForEach(CardColorScheme.allCases) { scheme in
                CardView(
                    card: Card(rank: .ace, suit: .spades),
                    width: 80, height: 120,
                    isDragging: false, faceUp: false,
                    colorScheme: scheme
                )
            }
        }
    }
}

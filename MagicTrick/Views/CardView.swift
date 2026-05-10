import SwiftUI

/// A single playing card with realistic 3D flip, paper texture, and dynamic lighting
struct CardView: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat
    let isDragging: Bool
    let faceUp: Bool
    /// Optional elevation (0 = resting, negative = lifted above). Affects shadow spread.
    var elevation: CGFloat = 0

    private var cornerRadius: CGFloat { width * 0.08 }
    /// Shadow radius scales with how high the card is "lifted" off the table
    private var shadowRadius: CGFloat {
        let base: CGFloat = isDragging ? 14 : 5
        let liftBonus = abs(elevation) * 0.04
        return base + liftBonus
    }
    private var shadowOffsetY: CGFloat {
        let base: CGFloat = isDragging ? 10 : 3
        let liftBonus = abs(elevation) * 0.025
        return base + liftBonus
    }
    private var shadowOpacity: Double {
        let base: Double = isDragging ? 0.6 : 0.35
        let liftBonus = Double(abs(elevation)) * 0.001
        return min(base + liftBonus, 0.8)
    }

    var body: some View {
        ZStack {
            // Card back (visible when face-down)
            cardBack
                .opacity(faceUp ? 0 : 1)
                .rotation3DEffect(
                    .degrees(faceUp ? 90 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )

            // Card face (visible when face-up)
            cardFace
                .opacity(faceUp ? 1 : 0)
                .rotation3DEffect(
                    .degrees(faceUp ? 0 : -90),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )

            // Light sweep highlight — flashes across the card during flip
            if faceUp {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.0),
                                .white.opacity(0.18),
                                .white.opacity(0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(faceUp ? 1 : 0)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        // Card edge — thin white rim simulates paper edge thickness
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    Color.white.opacity(faceUp ? 0.08 : 0.15),
                    lineWidth: faceUp ? 0.5 : 0.8
                )
        )
        // Paper edge stack effect when face-down (multiple card illusion)
        .overlay(
            Group {
                if !faceUp {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1.5)
                        .offset(y: 1.5)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            }
        )
        .shadow(
            color: .black.opacity(shadowOpacity),
            radius: shadowRadius,
            x: 0,
            y: shadowOffsetY
        )
    }

    // MARK: - Card Back — Realistic Playing Card

    private var cardBack: some View {
        ZStack {
            // Rich royal blue base
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(red: 0.10, green: 0.15, blue: 0.30))

            // Subtle paper texture — fine cross-hatch pattern
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.03),
                            Color.clear,
                            Color.white.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Radial sheen — light source from top-left
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: width * 0.8
                    )
                )

            // Thin inner border — classic card back frame
            RoundedRectangle(cornerRadius: cornerRadius - 2)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                .padding(4)

            // Inner decorative border
            RoundedRectangle(cornerRadius: cornerRadius - 5)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.3)
                .padding(7)

            // Centered diamond outline
            CardDiamond()
                .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
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
            .fill(Color.white.opacity(0.35))
            .frame(width: 2.5, height: 2.5)
            .position(x: x, y: y)
    }

    // MARK: - Card Face — Realistic Paper Stock

    private var cardFace: some View {
        ZStack {
            // Cream white paper background
            Color(red: 0.97, green: 0.97, blue: 0.95)

            // Subtle paper grain texture
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.015),
                            Color.clear,
                            Color.black.opacity(0.01),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

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

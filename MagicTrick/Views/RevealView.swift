import SwiftUI

/// Clean reveal overlay — card flips face-up, no buttons, rotate to portrait to dismiss
struct RevealView: View {
    let card: Card

    @State private var appeared = false
    @State private var flipAngle: Double = 90

    private let revealCardWidth: CGFloat = 140
    private let revealCardHeight: CGFloat = 210

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(appeared ? 0.7 : 0)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // The revealed card — clean flip animation
                CardView(
                    card: card,
                    width: revealCardWidth,
                    height: revealCardHeight,
                    isDragging: false,
                    faceUp: true
                )
                .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                .opacity(appeared ? 1 : 0)

                // Card name — plain white
                Text(card.fullName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                flipAngle = 0
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RevealView(card: Card(rank: .ace, suit: .spades))
    }
}

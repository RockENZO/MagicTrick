import SwiftUI

enum AppTheme {
    case dark
    case light

    static func current(from scheme: ColorScheme) -> AppTheme {
        scheme == .dark ? .dark : .light
    }
}

extension AppTheme {
    var backgroundGradient: LinearGradient {
        switch self {
        case .dark:
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.15),
                    Color(red: 0.03, green: 0.05, blue: 0.10),
                    Color(red: 0.01, green: 0.02, blue: 0.05),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .light:
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.98, blue: 0.97),
                    Color(red: 0.95, green: 0.95, blue: 0.94),
                    Color(red: 0.93, green: 0.93, blue: 0.92),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

extension AppTheme {
    struct CardBackStyle {
        let fill: Color
        let borderColor: Color
        let borderOpacity: Double
        let sheenOpacity: Double
        let monogramColor: Color
        let monogramOpacity: Double
        let monogramLineWidth: CGFloat
        let dotColor: Color
        let dotOpacity: Double
    }

    struct CardFaceStyle {
        let fill: Color
        let borderOpacity: Double
    }

    var cardBack: CardBackStyle {
        switch self {
        case .dark:
            CardBackStyle(
                fill: Color(red: 0.10, green: 0.15, blue: 0.30),
                borderColor: .white,
                borderOpacity: 0.18,
                sheenOpacity: 0.08,
                monogramColor: .white,
                monogramOpacity: 0.25,
                monogramLineWidth: 0.8,
                dotColor: .white,
                dotOpacity: 0.35
            )
        case .light:
            CardBackStyle(
                fill: Color(red: 0.94, green: 0.92, blue: 0.88),
                borderColor: Color(red: 0.35, green: 0.33, blue: 0.30),
                borderOpacity: 0.45,
                sheenOpacity: 0,
                monogramColor: Color(red: 0.35, green: 0.33, blue: 0.30),
                monogramOpacity: 0.35,
                monogramLineWidth: 0.6,
                dotColor: Color(red: 0.35, green: 0.33, blue: 0.30),
                dotOpacity: 0.45
            )
        }
    }

    var cardFace: CardFaceStyle {
        switch self {
        case .dark:
            CardFaceStyle(
                fill: Color(red: 0.97, green: 0.97, blue: 0.95),
                borderOpacity: 0.05
            )
        case .light:
            CardFaceStyle(
                fill: Color(red: 0.97, green: 0.97, blue: 0.95),
                borderOpacity: 0.08
            )
        }
    }
}

extension AppTheme {
    var revealOverlayColor: Color {
        switch self {
        case .dark:
            Color.black
        case .light:
            Color(red: 0.95, green: 0.95, blue: 0.94)
        }
    }

    var revealLabelColor: Color {
        switch self {
        case .dark:
            .white
        case .light:
            Color(red: 0.1, green: 0.1, blue: 0.15)
        }
    }
}

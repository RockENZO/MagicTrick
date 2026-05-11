import SwiftUI

/// Apple-minimalist color schemes for cards and background.
enum CardColorScheme: Int, CaseIterable, Identifiable {
    case midnight = 0   // Current — deep navy, royal blue
    case obsidian       // Pure black, charcoal cards, silver
    case ember          // Dark warm slate, burgundy cards
    case sage           // Deep forest, muted emerald
    case arctic         // Cool gray, icy blue-white

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .midnight: return "Midnight"
        case .obsidian: return "Obsidian"
        case .ember:    return "Ember"
        case .sage:     return "Sage"
        case .arctic:   return "Arctic"
        }
    }

    // MARK: - Background Gradient

    var backgroundColors: [Color] {
        switch self {
        case .midnight:
            return [
                Color(red: 0.05, green: 0.08, blue: 0.15),
                Color(red: 0.03, green: 0.05, blue: 0.10),
                Color(red: 0.01, green: 0.02, blue: 0.05),
                .black
            ]
        case .obsidian:
            return [
                Color(red: 0.06, green: 0.06, blue: 0.07),
                Color(red: 0.03, green: 0.03, blue: 0.04),
                Color(red: 0.01, green: 0.01, blue: 0.02),
                .black
            ]
        case .ember:
            return [
                Color(red: 0.10, green: 0.06, blue: 0.06),
                Color(red: 0.06, green: 0.03, blue: 0.03),
                Color(red: 0.03, green: 0.01, blue: 0.01),
                .black
            ]
        case .sage:
            return [
                Color(red: 0.04, green: 0.08, blue: 0.06),
                Color(red: 0.02, green: 0.05, blue: 0.03),
                Color(red: 0.01, green: 0.02, blue: 0.01),
                .black
            ]
        case .arctic:
            return [
                Color(red: 0.08, green: 0.09, blue: 0.12),
                Color(red: 0.04, green: 0.05, blue: 0.08),
                Color(red: 0.02, green: 0.02, blue: 0.04),
                .black
            ]
        }
    }

    // MARK: - Card Back

    var cardBackBase: Color {
        switch self {
        case .midnight: return Color(red: 0.10, green: 0.15, blue: 0.30)
        case .obsidian: return Color(red: 0.12, green: 0.12, blue: 0.14)
        case .ember:    return Color(red: 0.28, green: 0.10, blue: 0.12)
        case .sage:     return Color(red: 0.08, green: 0.20, blue: 0.15)
        case .arctic:   return Color(red: 0.14, green: 0.16, blue: 0.24)
        }
    }

    var cardBackSheenOpacity: Double {
        switch self {
        case .midnight: return 0.08
        case .obsidian: return 0.12
        case .ember:    return 0.06
        case .sage:     return 0.06
        case .arctic:   return 0.10
        }
    }

    var cardBorderOpacity: Double {
        switch self {
        case .midnight: return 0.18
        case .obsidian: return 0.25
        case .ember:    return 0.15
        case .sage:     return 0.15
        case .arctic:   return 0.20
        }
    }

    var cardDiamondOpacity: Double {
        switch self {
        case .midnight: return 0.25
        case .obsidian: return 0.35
        case .ember:    return 0.20
        case .sage:     return 0.20
        case .arctic:   return 0.30
        }
    }

    var cornerDotOpacity: Double {
        switch self {
        case .midnight: return 0.35
        case .obsidian: return 0.45
        case .ember:    return 0.30
        case .sage:     return 0.30
        case .arctic:   return 0.40
        }
    }

    // MARK: - Card Face

    var cardFaceBackground: Color {
        switch self {
        case .midnight: return Color(red: 0.97, green: 0.97, blue: 0.95)
        case .obsidian: return Color(red: 0.95, green: 0.95, blue: 0.96)
        case .ember:    return Color(red: 0.98, green: 0.96, blue: 0.94)
        case .sage:     return Color(red: 0.95, green: 0.97, blue: 0.95)
        case .arctic:   return Color(red: 0.94, green: 0.95, blue: 0.98)
        }
    }

    // MARK: - Reveal Overlay

    var revealOverlayOpacity: Double {
        switch self {
        case .midnight: return 0.7
        case .obsidian: return 0.75
        case .ember:    return 0.65
        case .sage:     return 0.65
        case .arctic:   return 0.7
        }
    }
}

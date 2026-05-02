import Foundation

/// Simplified state machine — no text prompts, orientation-driven transitions
enum TrickPhase: Equatable {
    /// Portrait, stacked deck, waiting for landscape rotation
    case idle

    /// Landscape, cards fanned out (spectator picks OR magician reveals)
    case spread

    /// Portrait, shake-triggered shuffle animation looping
    case shuffling

    /// Landscape, card being revealed
    case reveal
}

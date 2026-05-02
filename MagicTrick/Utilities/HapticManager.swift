import UIKit

/// Provides haptic feedback for the magic trick.
/// The "magic signal" is the secret feedback only the magician feels.
final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    // MARK: - Secret Magic Signal
    /// Triple-buzz pattern — only the magician knows this means "the card is locked in"
    func magicSignal() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()

        let now = DispatchTime.now()
        DispatchQueue.main.asyncAfter(deadline: now) {
            generator.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: now + 0.15) {
            generator.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: now + 0.30) {
            generator.impactOccurred(intensity: 0.8)
        }
    }

    // MARK: - Card Flip
    /// Light tap when a card flips face-up or face-down
    func cardFlip() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // MARK: - Shuffle
    /// Medium impact during shuffle animation
    func shuffle() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - Reveal
    /// Success notification when the card is revealed
    func reveal() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Drag Start
    /// Soft impact when starting to drag a card
    func dragStart() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    // MARK: - Button Tap
    /// Rigid impact for action buttons
    func buttonTap() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
}

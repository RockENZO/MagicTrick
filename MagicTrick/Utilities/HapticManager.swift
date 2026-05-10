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
    /// Light tap when a card flips face-up or face-down — like a fingernail tap on paper
    func cardFlip() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.7)
    }

    // MARK: - Card Snap
    /// Quick rigid impact when a card snaps into position (e.g. settling after drag)
    func cardSnap() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred(intensity: 0.5)
    }

    // MARK: - Card Lift
    /// Soft impact when lifting a card off the table/fan
    func cardLift() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.4)
    }

    // MARK: - Card Drop
    /// Medium impact when a card lands on the deck — like paper hitting felt
    func cardDrop() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 0.8)
    }

    // MARK: - Shuffle
    /// Medium impact during shuffle animation — rhythmic paper riffle feel
    func shuffle() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 0.6)
    }

    // MARK: - Shuffle Settle
    /// Soft impact when the deck settles after shuffling
    func shuffleSettle() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.5)
    }

    // MARK: - Reveal
    /// Success notification when the card is revealed — triumphant feel
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

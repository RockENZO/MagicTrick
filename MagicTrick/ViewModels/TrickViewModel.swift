import SwiftUI
import Combine

/// Core game logic: orientation-driven, shake-shuffle, secret magic trigger
final class TrickViewModel: ObservableObject {

    // MARK: - Published State
    @Published var deck: [Card] = []
    @Published var phase: TrickPhase = .idle
    @Published var chosenCard: Card? = nil
    @Published var revealCard: Card? = nil

    // Shuffle animation state — per-card vertical + lateral offset for riffle effect
    @Published var shuffleOffsets: [CGFloat] = []
    @Published var shuffleLateral: [CGFloat] = []
    @Published var isShuffling = false

    // Peek state — card being dragged, follows finger
    @Published var peekedCardID: UUID? = nil
    @Published var peekLift: CGFloat = 0        // Current Y offset (0 = rest, negative = up)

    // ★ THE SECRET: true only when corner is tapped during shuffling
    @Published var magicTriggered = false

    // MARK: - Private State
    private var originalDeck: [Card] = []
    private var shuffleWorkItem: DispatchWorkItem?
    private var peekTimer: DispatchWorkItem?
    private var hasFlipped = false              // Whether peeked card has been flipped face-up

    // Tracks whether spectator has picked a card this round
    private(set) var hasPickedCard = false
    // Tracks whether reveal has happened
    private var hasRevealed = false

    // MARK: - Init
    init() {
        resetDeck()
    }

    // MARK: - Deck Management
    func resetDeck() {
        var d = Deck()
        d.shuffle()
        deck = d.cards
        originalDeck = d.cards
        chosenCard = nil
        revealCard = nil
        isShuffling = false
        shuffleOffsets = []
        shuffleLateral = []
        peekedCardID = nil
        peekLift = 0
        hasFlipped = false
        magicTriggered = false
        hasPickedCard = false
        hasRevealed = false
        shuffleWorkItem?.cancel()
        shuffleWorkItem = nil
        peekTimer?.cancel()
        peekTimer = nil
        phase = .idle
    }

    // MARK: - Orientation Handlers

    func onRotateToLandscape() {
        switch phase {
        case .idle:
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = .spread
            }
        case .shuffling:
            // Stop any in-flight shuffle animation
            isShuffling = false
            shuffleWorkItem?.cancel()
            shuffleWorkItem = nil
            settleShuffle()

            hasRevealed = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = .spread
            }
        default:
            break
        }
    }

    func onRotateToPortrait() {
        switch phase {
        case .reveal:
            withAnimation(.easeInOut(duration: 0.4)) {
                resetDeck()
            }
        case .spread:
            // Cancel any peek timer
            peekTimer?.cancel()
            peekTimer = nil

            // Flip any peeked card back face-down
            if let cardID = peekedCardID, let idx = deck.firstIndex(where: { $0.id == cardID }) {
                deck[idx].isFaceUp = false
            }
            peekedCardID = nil
            peekLift = 0
            hasFlipped = false

            if hasRevealed || revealCard != nil {
                withAnimation(.easeInOut(duration: 0.4)) {
                    resetDeck()
                }
            } else if hasPickedCard || chosenCard != nil {
                hasPickedCard = true
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    phase = .idle
                }
            } else {
                withAnimation(.easeInOut(duration: 0.4)) {
                    phase = .idle
                }
            }
        default:
            break
        }
    }

    // MARK: - Peek Flow (finger-following drag)

    /// Finger touched a card — start tracking, no flip yet
    func beginPeek(id: UUID) {
        guard phase == .spread else { return }

        // Cancel any existing peek timer
        peekTimer?.cancel()
        peekTimer = nil

        // Reset previous peeked card if any
        if let prevID = peekedCardID, let prevIdx = deck.firstIndex(where: { $0.id == prevID }) {
            deck[prevIdx].isFaceUp = false
        }

        peekedCardID = id
        peekLift = 0
        hasFlipped = false
        HapticManager.shared.cardFlip()

        // Remember this card for the trick (only when spectator is picking)
        if !hasPickedCard {
            chosenCard = deck.first(where: { $0.id == id })
        }
    }

    /// Finger moved — update lift offset, flip at threshold
    func updatePeekLift(to newLift: CGFloat) {
        peekLift = newLift

        // Flip card face-up once dragged past threshold
        if newLift < -50 && !hasFlipped {
            hasFlipped = true
            if let id = peekedCardID, let idx = deck.firstIndex(where: { $0.id == id }) {
                // ★ MAGIC: transform dragged card into audience's card
                // Replace card data in-place (same IDs) so ForEach identity is preserved
                // and the gesture keeps tracking this card
                if magicTriggered,
                   let chosen = chosenCard,
                   let chosenIdx = deck.firstIndex(where: { $0.id == chosen.id }),
                   chosenIdx != idx {
                    let draggedRank = deck[idx].rank
                    let draggedSuit = deck[idx].suit
                    deck[idx] = Card(rank: chosen.rank, suit: chosen.suit, id: deck[idx].id)
                    deck[chosenIdx] = Card(rank: draggedRank, suit: draggedSuit, id: deck[chosenIdx].id)
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    deck[idx].isFaceUp = true
                }
            }
        }
    }

    /// Finger lifted — either cancel (didn't drag far enough) or commit
    func releasePeek(at index: Int) {
        guard let cardID = peekedCardID else { return }

        if !hasFlipped {
            // Didn't drag far enough — just reset
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                peekLift = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.peekedCardID = nil
            }
            return
        }

        if !hasPickedCard {
            // SPECTATOR PICKING: card is face-up, start 1-second timer then gravitate back
            let timer = DispatchWorkItem { [weak self] in
                self?.endPeek()
            }
            peekTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: timer)
        } else {
            // MAGICIAN REVEALING: reveal this card immediately
            // (when magic triggered, chosen card is already at the far right)
            revealCard = deck[index]
            hasRevealed = true

            // Clear peek state
            peekedCardID = nil
            peekLift = 0
            hasFlipped = false

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                phase = .reveal
            }

            HapticManager.shared.reveal()
        }
    }

    /// Timer fired (picking only) — flip card back and gravitate to position
    private func endPeek() {
        guard let cardID = peekedCardID else { return }

        peekTimer?.cancel()
        peekTimer = nil

        // Flip card back face-down
        if let idx = deck.firstIndex(where: { $0.id == cardID }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                deck[idx].isFaceUp = false
            }
        }

        hasPickedCard = true

        // Animate lift back to 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            peekLift = 0
        }

        // Clear peeked card after flip animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.peekedCardID = nil
            self?.hasFlipped = false
        }
    }

    // MARK: - Shake-Driven Shuffle

    func onShakeStart() {
        guard phase == .idle, chosenCard != nil else { return }
        phase = .shuffling
        isShuffling = true
        shuffleOffsets = Array(repeating: 0, count: deck.count)
        shuffleLateral = Array(repeating: 0, count: deck.count)
        startShuffleLoop()
    }

    func onShakeEnd() {
        guard phase == .shuffling else { return }
        isShuffling = false
        shuffleWorkItem?.cancel()
        shuffleWorkItem = nil
        settleShuffle()
    }

    /// Dramatic overhand riffle — big lifts, wide lateral spread, fast cadence
    private func startShuffleLoop() {
        guard isShuffling else { return }

        let count = deck.count
        let halfPoint = count / 2

        // Phase 1: Lift right half HIGH with staggered heights + lateral fan
        var lifted: [CGFloat] = Array(repeating: 0, count: count)
        var lateral: [CGFloat] = Array(repeating: 0, count: count)

        for i in 0..<count {
            if i >= halfPoint {
                let progress = CGFloat(i - halfPoint) / CGFloat(halfPoint)
                lifted[i] = -200 - progress * 120   // 200–320pt rise
                lateral[i] = 30 + progress * 40      // 30–70pt lateral fan
            }
        }

        withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
            shuffleOffsets = lifted
            shuffleLateral = lateral
        }

        HapticManager.shared.shuffle()

        // Phase 2: Drop + interleave + spring bounce
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isShuffling else { return }

            let midpoint = count / 2
            let left = Array(self.deck[0..<midpoint])
            let right = Array(self.deck[midpoint..<count])

            var interleaved: [Card] = []
            let maxCount = max(left.count, right.count)
            for i in 0..<maxCount {
                if i < right.count { interleaved.append(right[i]) }
                if i < left.count { interleaved.append(left[i]) }
            }

            // Overshoot the drop slightly past 0 for a slam effect
            withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
                self.shuffleOffsets = Array(repeating: 12, count: count)  // overshoot below
                self.shuffleLateral = Array(repeating: 0, count: count)
                self.deck = interleaved
            }

            // Settle overshoot back to 0
            let settleItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    self.shuffleOffsets = Array(repeating: 0, count: count)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: settleItem)

            // Loop if still shaking
            let loopItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.isShuffling {
                    self.startShuffleLoop()
                }
            }
            self.shuffleWorkItem = loopItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: loopItem)
        }

        shuffleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    /// When shaking stops, settle the deck with chosen card at known position
    private func settleShuffle() {
        var settled = deck
        if let chosen = chosenCard,
           let idx = settled.firstIndex(where: { $0.id == chosen.id }) {
            let removed = settled.remove(at: idx)
            let target = min(3, settled.count)
            settled.insert(removed, at: target)
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
            shuffleOffsets = Array(repeating: 0, count: settled.count)
            shuffleLateral = Array(repeating: 0, count: settled.count)
            deck = settled
        }
    }

    // MARK: - Secret Trigger
    func secretTriggerTapped() {
        guard phase == .shuffling else { return }
        magicTriggered = true
        HapticManager.shared.magicSignal()
    }
}

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

    // Hover state — finger is over a card (browsing the fan)
    @Published var hoveredCardID: UUID? = nil

    // Peek state — card being dragged out, follows finger (2D once flipped)
    @Published var peekedCardID: UUID? = nil
    @Published var peekOffset: CGSize = .zero

    // ★ THE SECRET: true only when corner is tapped during shuffling
    @Published var magicTriggered = false

    // MARK: - Private State
    private var originalDeck: [Card] = []
    private var shuffleWorkItem: DispatchWorkItem?
    private var peekTimer: DispatchWorkItem?
    private var hasFlipped = false              // Whether peeked card has been flipped face-up
    private var lastDragTime: Date = Date()
    private var lastDragOffset: CGSize = .zero
    private var touchStartY: CGFloat = 0        // Y position when finger first touched

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
        hoveredCardID = nil
        peekedCardID = nil
        peekOffset = .zero
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
        // Phase change is INSTANT — DeckView handles animation via screen-size interpolation
        // Clear any active peek
        hoveredCardID = nil
        peekedCardID = nil
        peekOffset = .zero
        hasFlipped = false

        switch phase {
        case .idle:
            phase = .spread
        case .returning:
            // User rotated back to landscape mid-return — clean up round state
            // and start fresh fan spread
            for i in deck.indices where deck[i].isFaceUp {
                deck[i].isFaceUp = false
            }
            chosenCard = nil
            revealCard = nil
            hasRevealed = false
            hasPickedCard = false
            magicTriggered = false
            phase = .spread
        case .shuffling:
            isShuffling = false
            shuffleWorkItem?.cancel()
            shuffleWorkItem = nil
            settleShuffle()

            hasRevealed = false
            phase = .spread
        default:
            break
        }
    }

    func onRotateToPortrait() {
        // Clear any active peek
        peekTimer?.cancel()
        peekTimer = nil
        if let cardID = peekedCardID, let idx = deck.firstIndex(where: { $0.id == cardID }) {
            deck[idx].isFaceUp = false
        }
        hoveredCardID = nil
        peekedCardID = nil
        peekOffset = .zero
        hasFlipped = false

        switch phase {
        case .reveal:
            // Phase change is instant — RevealView handles flip-back + slide animation
            // and calls finishReturn() via callback when done
            phase = .returning
        case .spread:
            if hasRevealed || revealCard != nil {
                withAnimation(.easeOut(duration: 0.3)) {
                    resetDeck()
                }
            } else if hasPickedCard || chosenCard != nil {
                hasPickedCard = true
                phase = .idle  // Instant — DeckView handles animation via interpolation
            } else {
                phase = .idle  // Instant
            }
        default:
            break
        }
    }

    // MARK: - Hover Flow (finger browsing across the fan)

    /// Finger touched the fan area — identify the card under the finger
    func beginHover(id: UUID) {
        guard phase == .spread else { return }
        hoveredCardID = id
        HapticManager.shared.cardLift()
    }

    /// Finger moved to a different card — switch hover target
    func updateHover(to id: UUID) {
        guard phase == .spread else { return }
        guard id != hoveredCardID else { return }
        hoveredCardID = id
    }

    /// Finger left all cards (or lifted) — clear hover
    func endHover() {
        hoveredCardID = nil
    }

    // MARK: - Peek Flow (swipe-up drag with physics)

    /// Finger swiped upward past threshold on a hovered card — begin full drag-out
    func beginPeek(id: UUID) {
        guard phase == .spread else { return }

        // Cancel any existing peek timer
        peekTimer?.cancel()
        peekTimer = nil

        // Reset previous peeked card if any
        if let prevID = peekedCardID, let prevIdx = deck.firstIndex(where: { $0.id == prevID }) {
            deck[prevIdx].isFaceUp = false
        }

        hoveredCardID = nil  // Hover transitions to peek
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            peekedCardID = id
        }
        peekOffset = .zero
        hasFlipped = false
        lastDragTime = Date()
        lastDragOffset = .zero
        HapticManager.shared.cardFlip()

        // Remember this card for the trick (only when spectator is picking)
        if !hasPickedCard {
            chosenCard = deck.first(where: { $0.id == id })
        }
    }

    /// Finger moved — update 2D offset, flip at Y threshold
    func updatePeekOffset(to newOffset: CGSize) {
        let now = Date()
        let dt = max(now.timeIntervalSince(lastDragTime), 0.001)

        // Before flipping, only allow upward movement (Y < 0)
        if !hasFlipped {
            let clampedY = min(0, newOffset.height)
            peekOffset = CGSize(width: 0, height: clampedY)
        } else {
            // After flipping, allow free 2D movement
            peekOffset = newOffset
        }

        // Flip card face-up once dragged past threshold
        if peekOffset.height < -50 && !hasFlipped {
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
                // Snappy spring flip — feels like a real card snap
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    deck[idx].isFaceUp = true
                }
                HapticManager.shared.cardFlip()
            }
        }

        lastDragOffset = newOffset
        lastDragTime = now
    }

    /// Finger lifted — either cancel (didn't drag far enough) or commit
    func releasePeek(at index: Int) {
        guard let cardID = peekedCardID else { return }

        if !hasFlipped {
            // Didn't drag far enough — spring back with momentum
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                peekOffset = .zero
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.peekedCardID = nil
            }
            return
        }

        if !hasPickedCard {
            // SPECTATOR PICKING: card is face-up, start 2-second timer then gravitate back
            let timer = DispatchWorkItem { [weak self] in
                self?.endPeek()
            }
            peekTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timer)
        } else {
            // MAGICIAN REVEALING: reveal this card immediately
            revealCard = deck[index]
            hasRevealed = true

            // Clear peek state
            peekedCardID = nil
            peekOffset = .zero
            hasFlipped = false

            withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {
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

        // Flip card back face-down — snappy spring
        if let idx = deck.firstIndex(where: { $0.id == cardID }) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                deck[idx].isFaceUp = false
            }
        }

        hasPickedCard = true

        // Animate card back to its spread position — natural spring with slight overshoot
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            peekOffset = .zero
        }

        // Clear peeked card after flip animation settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.peekedCardID = nil
            self?.hasFlipped = false
        }
    }

    // MARK: - Shake-Driven Shuffle

    func onShakeStart() {
        guard chosenCard != nil else { return }
        guard phase == .idle || phase == .shuffling else { return }

        // If already shuffling from a previous shake, just restart the loop
        if phase == .idle {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                phase = .shuffling
            }
        }
        isShuffling = true
        shuffleOffsets = Array(repeating: 0, count: deck.count)
        shuffleLateral = Array(repeating: 0, count: deck.count)
        shuffleWorkItem?.cancel()
        shuffleWorkItem = nil
        startShuffleLoop()
    }

    func onShakeEnd() {
        guard phase == .shuffling else { return }
        isShuffling = false
        shuffleWorkItem?.cancel()
        shuffleWorkItem = nil
        settleShuffle()
        // Transition to idle — explicit withAnimation since DeckView no longer uses .animation(value:) modifiers
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            phase = .idle
        }
    }

    /// Called after the return animation completes — clean up and go to idle
    func finishReturn() {
        guard phase == .returning else { return }
        // Reset any face-up deck cards (from the peek flow)
        for i in deck.indices where deck[i].isFaceUp {
            deck[i].isFaceUp = false
        }
        // Clear ALL round state so a new round can begin
        chosenCard = nil
        revealCard = nil
        hasRevealed = false
        hasPickedCard = false
        magicTriggered = false   // Reset secret trigger — must double-tap again each round
        hoveredCardID = nil
        peekedCardID = nil
        peekOffset = .zero
        hasFlipped = false
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .idle
        }
    }

    /// Dramatic overhand riffle — big lifts, wide lateral spread, fast cadence
    /// with per-card cascading timing for realistic paper feel
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
                // Cascading lift — cards further up rise higher with slight randomness
                let cascade = progress * progress  // Quadratic for natural acceleration
                lifted[i] = -180 - cascade * 140   // 180–320pt rise
                lateral[i] = 25 + progress * 45    // 25–70pt lateral fan
            }
        }

        // Staggered spring — each card starts its animation slightly after the one below it
        withAnimation(.spring(response: 0.2, dampingFraction: 0.72)) {
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

            // Slam down — overshoot past zero for bounce, then settle
            withAnimation(.spring(response: 0.2, dampingFraction: 0.48)) {
                self.shuffleOffsets = Array(repeating: 14, count: count)  // overshoot
                self.shuffleLateral = Array(repeating: 0, count: count)
                self.deck = interleaved
            }

            // Settle overshoot back to 0 — quick spring
            let settleItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
                    self.shuffleOffsets = Array(repeating: 0, count: count)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: settleItem)

            // Loop if still shaking
            let loopItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.isShuffling {
                    self.startShuffleLoop()
                }
            }
            self.shuffleWorkItem = loopItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: loopItem)
        }

        shuffleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
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
        // Note: phase doesn't change here — shuffling continues.
        // Phase will change on rotate-to-landscape (spread) or on shake-end (idle).
    }
}

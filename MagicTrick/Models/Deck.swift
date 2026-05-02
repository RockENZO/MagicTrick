import Foundation

struct Deck {
    private(set) var cards: [Card]

    /// Create a standard 52-card deck in order
    init() {
        cards = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(Card(rank: rank, suit: suit))
            }
        }
    }

    /// Create a deck from existing cards
    init(cards: [Card]) {
        self.cards = cards
    }

    var count: Int { cards.count }

    /// Fisher-Yates shuffle
    mutating func shuffle() {
        cards.shuffle()
    }

    /// Return a shuffled copy
    func shuffled() -> Deck {
        var copy = self
        copy.shuffle()
        return copy
    }

    /// Reset to a fresh 52-card deck in order
    mutating func reset() {
        self = Deck()
    }

    /// Get the top card without removing
    var topCard: Card? {
        cards.last
    }

    /// Remove and return the top card
    mutating func dealTop() -> Card? {
        cards.popLast()
    }

    /// Place a card on top of the deck
    mutating func placeOnTop(_ card: Card) {
        cards.append(card)
    }

    /// Find a card's index in the deck
    func index(of card: Card) -> Int? {
        cards.firstIndex(of: card)
    }

    /// Move a card to the top of the deck (secret control)
    mutating func moveCardToTop(_ card: Card) {
        guard let idx = index(of: card) else { return }
        let removed = cards.remove(at: idx)
        cards.append(removed)
    }

    /// Swap two cards by index
    mutating func swapCards(at i: Int, _ j: Int) {
        guard cards.indices.contains(i), cards.indices.contains(j) else { return }
        cards.swapAt(i, j)
    }
}

import SwiftUI

// MARK: - Rank
enum Rank: String, CaseIterable, Identifiable {
    case ace = "A"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case jack = "J"
    case queen = "Q"
    case king = "K"

    var id: String { rawValue }

    var displaySymbol: String {
        switch self {
        case .jack:  return "J"
        case .queen: return "Q"
        case .king:  return "K"
        case .ace:   return "A"
        default:     return rawValue
        }
    }

    /// SF Symbol name for face cards, nil for number cards
    var sfSymbol: String? {
        switch self {
        case .jack:  return "person.fill"
        case .queen: return "crown.fill"
        case .king:  return "person.fill.viewfinder"
        case .ace:   return "star.fill"
        default:     return nil
        }
    }
}

// MARK: - Suit
enum Suit: String, CaseIterable, Identifiable {
    case spades   = "♠"
    case hearts   = "♥"
    case diamonds = "♦"
    case clubs    = "♣"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .hearts, .diamonds:
            return Color(red: 0.85, green: 0.15, blue: 0.15)
        case .spades, .clubs:
            return Color(red: 0.1, green: 0.1, blue: 0.15)
        }
    }

    var name: String {
        switch self {
        case .spades:   return "Spades"
        case .hearts:   return "Hearts"
        case .diamonds: return "Diamonds"
        case .clubs:    return "Clubs"
        }
    }
}

// MARK: - Card
struct Card: Identifiable, Equatable, Hashable {
    let id: UUID
    let rank: Rank
    let suit: Suit
    var isFaceUp: Bool = false

    init(rank: Rank, suit: Suit, id: UUID = UUID()) {
        self.id = id
        self.rank = rank
        self.suit = suit
    }

    /// Short display name like "A♠"
    var shortName: String {
        "\(rank.displaySymbol)\(suit.rawValue)"
    }

    /// Full display name like "Ace of Spades"
    var fullName: String {
        let rankName: String
        switch rank {
        case .ace:   rankName = "Ace"
        case .two:   rankName = "Two"
        case .three: rankName = "Three"
        case .four:  rankName = "Four"
        case .five:  rankName = "Five"
        case .six:   rankName = "Six"
        case .seven: rankName = "Seven"
        case .eight: rankName = "Eight"
        case .nine:  rankName = "Nine"
        case .ten:   rankName = "Ten"
        case .jack:  rankName = "Jack"
        case .queen: rankName = "Queen"
        case .king:  rankName = "King"
        }
        return "\(rankName) of \(suit.name)"
    }

    static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Card rank (2–9, T, J, Q, K, A)
enum Rank: String, Codable, CaseIterable {
    case two   = "2"
    case three = "3"
    case four  = "4"
    case five  = "5"
    case six   = "6"
    case seven = "7"
    case eight = "8"
    case nine  = "9"
    case ten   = "T"
    case jack  = "J"
    case queen = "Q"
    case king  = "K"
    case ace   = "A"
}

/// Card suit (♣♦♥♠)
enum Suit: String, Codable, CaseIterable {
    case clubs    = "C"
    case diamonds = "D"
    case hearts   = "H"
    case spades   = "S"
}


enum Actions: String, Codable, CaseIterable {
    case check    = "CHECK"
    case call = "CALL"
    case bet   = "BET"
    case raise   = "RAISE"
    case fold    = "FOLD"
    case allin   = "ALLIN"
}

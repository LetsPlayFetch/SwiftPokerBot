import Foundation

enum OCRType {
    case cardRank, playerBet, playerBalance, playerAction, tablePot, baseOCR
}

extension OCRType: CaseIterable {
    public static var allCases: [OCRType] {
        return [.cardRank, .playerBet, .playerBalance, .playerAction, .tablePot, .baseOCR]
    }
}

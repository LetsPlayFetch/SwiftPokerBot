import Foundation

enum OCRType {
    case playerBet, playerBalance, playerAction, tablePot, baseOCR
}

extension OCRType: CaseIterable {
    public static var allCases: [OCRType] {
        return [.playerBet, .playerBalance, .playerAction, .tablePot, .baseOCR]
    }
}

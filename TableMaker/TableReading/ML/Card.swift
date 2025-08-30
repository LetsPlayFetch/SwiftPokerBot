import Foundation

struct Card: Codable, Equatable {
    let rank: String
    let suit: String
    
    static func parse(_ mlOutput: String) -> Card? {
        let cleaned = mlOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.lowercased() == "empty" || cleaned.isEmpty {
            return nil
        }
        
        // Last character is suit, everything else is rank
        guard cleaned.count >= 2 else { return nil }
        
        let suit = String(cleaned.suffix(1)).lowercased()
        let rank = String(cleaned.dropLast())
        
        // Normalize to T
        let normalizedRank = rank == "10" ? "T" : rank
        
        return Card(rank: normalizedRank, suit: suit)
    }
}

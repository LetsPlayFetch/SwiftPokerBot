import Foundation

/// Validation and correction functions for all OCR types
struct OCRValidation {
    
    // MARK: - Player Bet Validation
    
    /// Validate and format bet amount result
    static func validatePlayerBet(_ input: String?) -> String {
        guard let input = input?.trimmingCharacters(in: .whitespacesAndNewlines), 
              !input.isEmpty else {
            return ""
        }
        
        // Currently just returns input as-is
        // Can add formatting/validation later if needed
        return input
    }
    
    // MARK: - Player Balance Validation
    
    /// Validate and format balance result - FORCE last 2 chars to be "BB"
    static func validatePlayerBalance(_ input: String?) -> String {
        guard let input = input?.trimmingCharacters(in: .whitespacesAndNewlines), 
              !input.isEmpty else {
            return ""
        }
        
        var cleaned = input.replacingOccurrences(of: "$", with: "")
                          .replacingOccurrences(of: "£", with: "")
                          .replacingOccurrences(of: "€", with: "")
                          .replacingOccurrences(of: ",", with: "")
                          .replacingOccurrences(of: " ", with: "")
        
        // FORCE last 2 characters to be "BB" (handle both Latin B and Cyrillic В)
        if cleaned.count >= 2 {
            let lastTwo = cleaned.suffix(2).uppercased()
            
            // Check for Latin B, Cyrillic В (U+0412), or 8
            let containsB = lastTwo.contains("B") || lastTwo.contains("В") || lastTwo.contains("8")
            
            if containsB {
                cleaned = String(cleaned.dropLast(2)) + "BB"  // Force Latin BB
            }
        }
        
        // Extract numeric part (everything before "BB")
        let numericPart = cleaned.replacingOccurrences(of: "BB", with: "")
                                .trimmingCharacters(in: .whitespaces)
        
        if let _ = Double(numericPart) {
            return numericPart + " BB"
        }
        
        // Apply corrections to numeric part only
        let corrections: [String: String] = [
            "O": "0", "o": "0", "I": "1", "l": "1",
            "S": "5", "s": "5", "G": "6"
        ]
        
        var corrected = numericPart
        for (wrong, right) in corrections {
            corrected = corrected.replacingOccurrences(of: wrong, with: right)
        }
        
        if let _ = Double(corrected) {
            return corrected + " BB"
        }
        
        return input
    }
    
    // MARK: - Player Action Validation
    
    /// Validate and format action result
    static func validatePlayerAction(_ input: String?) -> String {
        guard let input = input?.trimmingCharacters(in: .whitespacesAndNewlines), 
              !input.isEmpty else {
            return ""
        }
        
        let validActions = ["Check", "Bet", "Call", "Fold", "Raise", "All In", "All-In", "Allin"]
        let upperInput = input.uppercased()
        
        // Direct match (case insensitive)
        for action in validActions {
            if upperInput == action.uppercased() {
                return action
            }
        }
        
        // Partial match for common OCR errors
        if upperInput.contains("CHECK") || upperInput.contains("CHE") {
            return "Check"
        }
        if upperInput.contains("BET") || upperInput.contains("BT") {
            return "Bet"
        }
        if upperInput.contains("CALL") || upperInput.contains("CAL") {
            return "Call"
        }
        if upperInput.contains("FOLD") || upperInput.contains("FOL") {
            return "Fold"
        }
        if upperInput.contains("RAISE") || upperInput.contains("RAS") {
            return "Raise"
        }
        if upperInput.contains("ALL") || upperInput.contains("ALLIN") {
            return "All In"
        }
        
        return input // Return original if no validation matches
    }
    
    // MARK: - Table Pot Validation
    
    /// Validate and format pot result - SAME AS PLAYER BALANCE (force BB suffix)
    static func validateTablePot(_ input: String?) -> String {
        guard let input = input?.trimmingCharacters(in: .whitespacesAndNewlines), 
              !input.isEmpty else {
            return ""
        }
        
        var cleaned = input.replacingOccurrences(of: "$", with: "")
                          .replacingOccurrences(of: "£", with: "")
                          .replacingOccurrences(of: "€", with: "")
                          .replacingOccurrences(of: ",", with: "")
                          .replacingOccurrences(of: " ", with: "")
        
        // FORCE last 2 characters to be "BB" (handle Latin B, Cyrillic В, or 8)
        if cleaned.count >= 2 {
            let lastTwo = cleaned.suffix(2).uppercased()
            
            // Check for Latin B, Cyrillic В (U+0412), or 8
            let containsB = lastTwo.contains("B") || lastTwo.contains("В") || lastTwo.contains("8")
            
            if containsB {
                cleaned = String(cleaned.dropLast(2)) + "BB"
            }
        }
        
        // Extract numeric part (everything before "BB")
        let numericPart = cleaned.replacingOccurrences(of: "BB", with: "")
                                .trimmingCharacters(in: .whitespaces)
        
        if let _ = Double(numericPart) {
            return numericPart + " BB"
        }
        
        // Apply corrections to numeric part only
        let corrections: [String: String] = [
            "O": "0", "o": "0", "I": "1", "l": "1",
            "S": "5", "s": "5", "G": "6"
        ]
        
        var corrected = numericPart
        for (wrong, right) in corrections {
            corrected = corrected.replacingOccurrences(of: wrong, with: right)
        }
        
        if let _ = Double(corrected) {
            return corrected + " BB"
        }
        
        return input
    }
}

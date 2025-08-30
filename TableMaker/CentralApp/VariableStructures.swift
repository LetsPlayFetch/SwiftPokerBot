import CoreGraphics
import SwiftUI

// Enum for variable types (numeric, name, action)
enum VariableType: String, CaseIterable, Codable, Identifiable {
    case numeric = "Numeric"
    case name    = "Name"
    case action  = "Action"

    var id: String { rawValue }
}

// Structure for a region box
struct RegionBox: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var rect: CGRect
    
}

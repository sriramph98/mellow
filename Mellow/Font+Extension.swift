import SwiftUI

extension Font {
    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Try to load SF Pro Rounded
        if let roundedFont = NSFont(name: "SF Pro Rounded", size: size) {
            return Font(roundedFont)
        }
        
        // Fallback to system rounded font
        return .system(size: size, weight: weight, design: .rounded)
    }
} 
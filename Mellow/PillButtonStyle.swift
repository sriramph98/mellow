import SwiftUI

struct PillButtonStyle: ButtonStyle {
    var customBackground: Color = Color.blue
    var minWidth: CGFloat = 0
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: minWidth)
            .background(
                Capsule()
                    .fill(customBackground)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
} 
import SwiftUI

struct PillButtonStyle: ButtonStyle {
    @State private var isHovering = false
    var minWidth: CGFloat? = 135
    var customBackground: Color? = nil
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 10) {
            configuration.label
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minWidth: minWidth, alignment: .center)
        .background(
            customBackground ?? (isHovering ? .black.opacity(0.3) : .white.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .strokeBorder(Color.white.opacity(0.14))
                .opacity(isHovering ? 1 : 0)
        )
        .animation(.smooth(duration: 0.2), value: isHovering)
        .cornerRadius(999)
        .onHover { hovering in
            withAnimation {
                isHovering = hovering
            }
        }
    }
} 
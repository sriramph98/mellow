import SwiftUI

struct CustomBlurView: NSViewRepresentable {
    enum BlurStyle {
        case primary
        case light
        case dark
        case ultraDark
        case titlebar
        case thinMaterial
        case thickMaterial
        case vibrantLight
        case vibrantDark
    }
    
    let style: BlurStyle
    var cornerRadius: CGFloat = 0
    var opacity: CGFloat = 1.0
    var additionalEffects: Bool = false
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        
        // Configure the visual style
        switch style {
        case .primary:
            view.material = .fullScreenUI
            view.blendingMode = .behindWindow
        case .light:
            view.material = .sheet
            view.blendingMode = .behindWindow
            view.appearance = NSAppearance(named: .aqua)
        case .dark:
            view.material = .sheet
            view.blendingMode = .behindWindow
            view.appearance = NSAppearance(named: .darkAqua)
        case .ultraDark:
            view.material = .hudWindow
            view.blendingMode = .behindWindow
            view.appearance = NSAppearance(named: .darkAqua)
        case .titlebar:
            view.material = .titlebar
            view.blendingMode = .behindWindow
        case .thinMaterial:
            view.material = .contentBackground
            view.blendingMode = .behindWindow
        case .thickMaterial:
            view.material = .popover
            view.blendingMode = .behindWindow
        case .vibrantLight:
            view.material = .underWindowBackground
            view.blendingMode = .withinWindow
            view.appearance = NSAppearance(named: .aqua)
        case .vibrantDark:
            view.material = .underWindowBackground
            view.blendingMode = .withinWindow
            view.appearance = NSAppearance(named: .darkAqua)
        }
        
        // Configure visual properties
        view.state = .active
        view.wantsLayer = true
        
        if cornerRadius > 0 {
            view.layer?.cornerRadius = cornerRadius
            view.layer?.masksToBounds = true
        }
        
        view.alphaValue = opacity
        
        // Add additional effects if requested
        if additionalEffects, let layer = view.layer {
            // Add subtle border
            layer.borderWidth = 0.5
            layer.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
            
            // Add subtle shadow
            layer.shadowOpacity = 0.15
            layer.shadowRadius = 10
            layer.shadowOffset = CGSize(width: 0, height: 5)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // Update appearance if needed
        if cornerRadius > 0 {
            nsView.layer?.cornerRadius = cornerRadius
        }
        
        nsView.alphaValue = opacity
    }
}

// Convenience initializers for common use cases
extension CustomBlurView {
    static func card(cornerRadius: CGFloat = 16) -> CustomBlurView {
        CustomBlurView(
            style: .dark,
            cornerRadius: cornerRadius,
            additionalEffects: true
        )
    }
    
    static func modal(cornerRadius: CGFloat = 20) -> CustomBlurView {
        CustomBlurView(
            style: .ultraDark,
            cornerRadius: cornerRadius,
            additionalEffects: true
        )
    }
    
    static func toolbar() -> CustomBlurView {
        CustomBlurView(
            style: .thinMaterial,
            cornerRadius: 10,
            additionalEffects: false
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        CustomBlurView.card()
            .frame(width: 200, height: 100)
        
        CustomBlurView.modal()
            .frame(width: 200, height: 100)
            
        CustomBlurView.toolbar()
            .frame(width: 200, height: 50)
            
        CustomBlurView(style: .vibrantDark, cornerRadius: 12, additionalEffects: true)
            .frame(width: 200, height: 100)
    }
    .padding(50)
    .background(Color.gray.opacity(0.3))
} 
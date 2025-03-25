import SwiftUI

struct WindowBlurView: NSViewRepresentable {
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
    var backgroundTint: Color? = nil
    
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
        
        // Add background tint if specified
        if let backgroundTint = backgroundTint, let layer = view.layer {
            // Convert SwiftUI Color to NSColor safely
            let nsColor = NSColor(backgroundTint)
            layer.backgroundColor = nsColor.withAlphaComponent(0.3).cgColor
        } else if let layer = view.layer {
            // Default subtle background overlay for better visibility
            layer.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        }
        
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
extension WindowBlurView {
    static func darkOverlay() -> WindowBlurView {
        WindowBlurView(
            style: .ultraDark,
            opacity: 1.0,
            backgroundTint: Color.black
        )
    }
    
    static func accessoryPanel(cornerRadius: CGFloat = 16) -> WindowBlurView {
        WindowBlurView(
            style: .dark,
            cornerRadius: cornerRadius,
            additionalEffects: true,
            backgroundTint: Color.gray
        )
    }
    
    static func prominentPanel() -> WindowBlurView {
        WindowBlurView(
            style: .vibrantDark,
            cornerRadius: 20,
            additionalEffects: true,
            backgroundTint: Color(red: 0.2, green: 0.2, blue: 0.3)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        WindowBlurView.darkOverlay()
            .frame(width: 200, height: 100)
        
        WindowBlurView.accessoryPanel()
            .frame(width: 200, height: 100)
        
        WindowBlurView.prominentPanel()
            .frame(width: 200, height: 100)
            
        WindowBlurView(style: .vibrantDark, cornerRadius: 12, additionalEffects: true)
            .frame(width: 200, height: 100)
    }
    .padding(50)
    .background(Color.gray.opacity(0.3))
} 
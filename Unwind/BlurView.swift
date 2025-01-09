import SwiftUI
import Combine

public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    init(
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        
        // Force dark appearance for consistent look
        if let darkAppearance = NSAppearance(named: .darkAqua) {
            visualEffectView.appearance = darkAppearance
        }
        
        return visualEffectView
    }
    
    public func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct BlurView: View {
    let technique: String
    let screen: NSScreen
    let pomodoroCount: Int
    @State private var timeRemaining: TimeInterval
    @State var isAppearing = false
    @Binding var isAnimatingOut: Bool
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var wallpaperImage: NSImage?
    
    init(technique: String, screen: NSScreen, pomodoroCount: Int, isAnimatingOut: Binding<Bool>) {
        self.technique = technique
        self.screen = screen
        self.pomodoroCount = pomodoroCount
        self._isAnimatingOut = isAnimatingOut
        
        let duration: TimeInterval
        switch technique {
        case "20-20-20 Rule":
            duration = 20
        case "Pomodoro Technique":
            duration = pomodoroCount >= 4 ? 1800 : 300
        case "Custom":
            duration = TimeInterval(UserDefaults.standard.integer(forKey: "breakDuration"))
        default:
            duration = 20
        }
        self._timeRemaining = State(initialValue: duration)
    }
    
    // Get screen width for relative sizing
    private var screenWidth: CGFloat {
        NSScreen.main?.frame.width ?? 1440
    }
    
    private func handleSkip() {
        // Trigger fade out animation first
        withAnimation(
            .spring(
                response: 0.5,
                dampingFraction: 0.8,
                blendDuration: 0
            )
        ) {
            isAnimatingOut = true
            isAppearing = false
        }
        
        // Delay the actual skip action until animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.skipBreak()
            }
        }
    }
    
    private var content: (title: String, description: String) {
        switch technique {
        case "20-20-20 Rule":
            return (
                "Time for a Quick Reset!",
                "Look 20 feet away for 20 seconds."
            )
        case "Pomodoro Technique":
            let isLongBreak = (pomodoroCount >= 4)
            return (
                isLongBreak ? "Time for a Long Break!" : "Quick Break Time!",
                isLongBreak ? 
                    "Great work on completing 4 sessions!\nTake 30 minutes to recharge completely." :
                    "One Pomodoro down! Take 5 minutes to stretch and reset."
            )
        case "Custom":
            return (
                "Time for a Break!",
                "Step away from your screen.\nGive yourself a well-deserved rest."
            )
        default:
            return (
                "Break Time!",
                "Take a moment to reset."
            )
        }
    }
    
    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "\(seconds)s"
        }
    }
    
    private func getSystemWallpaper() -> NSImage? {
        if let workspace = NSWorkspace.shared.desktopImageURL(for: screen),
           let image = NSImage(contentsOf: workspace) {
            return image
        }
        return nil
    }
    
    var body: some View {
        ZStack {
            // System wallpaper with improved animation
            if let wallpaperImage = wallpaperImage {
                Image(nsImage: wallpaperImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }
            
            // Dark background overlay with smoother transition
            Color.black
                .opacity(0.8)
                .transition(.opacity)
            
            // Subtle blur with improved animation
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .withinWindow
            )
            .transition(.opacity)
            
            // Content with smoother animation
            VStack(spacing: 40) {
                Spacer()
                
                // Title
                Text(content.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Instructions
                Text(content.description)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                
                // Timer
                Text(formattedTime)
                    .font(.system(size: 56, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                Spacer()
                
                // Skip button
                Button(action: handleSkip) {
                    HStack(spacing: 8) {
                        Text("Skip")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background {
                        Capsule()
                            .fill(.white.opacity(0.2))
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(isAnimatingOut ? 0 : 1)  // Fade out with content
                
                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.02)),
                    removal: .opacity.combined(with: .scale(scale: 0.98))
                )
            )
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
        .onAppear {
            // Preload wallpaper before animation starts
            wallpaperImage = getSystemWallpaper()
            
            // Smoother entrance animation
            withAnimation(
                .spring(
                    response: 0.6,
                    dampingFraction: 0.8,
                    blendDuration: 0
                )
            ) {
                isAppearing = true
            }
        }
        .opacity(isAppearing ? 1 : 0)
        .onChange(of: isAnimatingOut) { oldValue, newValue in
            if newValue {
                // Smooth exit animation
                withAnimation(
                    .spring(
                        response: 0.5,
                        dampingFraction: 0.8,
                        blendDuration: 0
                    )
                ) {
                    isAppearing = false
                }
            }
        }
    }
}

// Updated animation modifiers
struct FadeScaleModifier: ViewModifier {
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.98)
            .animation(
                .spring(
                    response: 0.5,
                    dampingFraction: 0.8,
                    blendDuration: 0
                ),
                value: isVisible
            )
    }
}

struct ContentAnimationModifier: ViewModifier {
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.98)
            .animation(
                .spring(
                    response: 0.6,
                    dampingFraction: 0.8,
                    blendDuration: 0
                ),
                value: isVisible
            )
    }
}

#Preview {
    BlurView(
        technique: "20-20-20 Rule",
        screen: NSScreen.main ?? NSScreen(),
        pomodoroCount: 0,
        isAnimatingOut: .constant(false)
    )
}
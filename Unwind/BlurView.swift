import SwiftUI
import Combine

struct BlurView: View {
    let technique: String
    @State private var timeRemaining: TimeInterval = 20
    @State var isAppearing = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Get screen width for relative sizing
    private var screenWidth: CGFloat {
        NSScreen.main?.frame.width ?? 1440
    }
    
    private func handleSkip() {
        withAnimation(.easeOut(duration: 0.3)) {
            isAppearing = false
        }
        
        // Delay the actual dismissal to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.skipBreak()
            }
        }
    }
    
    private var content: (title: String, description: String) {
        switch technique {
        case "20-20-20":
            return (
                "Time for a Quick Reset!",
                "Look 20 feet away for 20 seconds."
            )
        case "Pomodoro":
            return (
                "Pause and Power Up",
                "You’ve earned it!\nStretch, walk around, or grab a drink."
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
    
    var body: some View {
        ZStack {
            // Dark background with blur
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .opacity(isAppearing ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: isAppearing)
            
            // Additional dark overlay for 80% opacity
            Color.black.opacity(0.6)
                .opacity(isAppearing ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: isAppearing)
            
            // Content
            VStack(spacing: 40) {
                Spacer()
                
                // Title
                Text(content.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Divider()
                    .frame(width: screenWidth * 0.6)  // 60% of screen width
                    .background(.white.opacity(0.3))
                
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
                
                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(isAppearing ? 1 : 0.8)
            .opacity(isAppearing ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isAppearing)
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
        .onAppear {
            if let duration = getBreakDuration() {
                timeRemaining = duration
            }
            // Trigger animations after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAppearing = true
            }
        }
        .onDisappear {
            isAppearing = false
        }
    }
    
    private func getBreakDuration() -> TimeInterval? {
        switch technique {
        case "20-20-20":
            return 20
        case "Pomodoro":
            return 300
        case "Custom":
            return TimeInterval(UserDefaults.standard.integer(forKey: "breakDuration"))
        default:
            return nil
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        
        // Force dark appearance
        if let darkAppearance = NSAppearance(named: .darkAqua) {
            visualEffectView.appearance = darkAppearance
        }
        
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
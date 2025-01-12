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

// Add this view to handle key events
struct KeyEventHandlingView: NSViewRepresentable {
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> KeyEventHandlingNSView {
        let view = KeyEventHandlingNSView()
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: KeyEventHandlingNSView, context: Context) {
        nsView.onEscape = onEscape
    }
}

class KeyEventHandlingNSView: NSView {
    var onEscape: (() -> Void)?
    private var focusTimer: Timer?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        // Stop existing timer if any
        focusTimer?.invalidate()
        
        guard let window = self.window else { return }
        
        // Become first responder immediately
        window.makeFirstResponder(self)
        
        // Set up a timer to maintain focus
        focusTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let window = self.window,
                  window.isVisible else { return }
            
            // Check if window should be key (internal display)
            let isInternalDisplay = window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber") as NSDeviceDescriptionKey] as? CGDirectDisplayID == CGMainDisplayID()
            
            if isInternalDisplay {
                // Ensure window is key and first responder
                if !window.isKeyWindow {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
                
                if window.firstResponder !== self {
                    window.makeFirstResponder(self)
                }
            }
        }
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            focusTimer?.invalidate()
            focusTimer = nil
        }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onEscape?()
        }
    }
}

struct BlurView: View {
    let technique: String
    let screen: NSScreen
    let pomodoroCount: Int
    @State private var timeRemaining: TimeInterval
    @State var isAppearing = false
    @Binding var isAnimatingOut: Bool
    let showContent: Bool
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var wallpaperImage: NSImage?
    @State private var escapeCount = 0
    @State private var currentTime = Date()
    private let timeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(
        technique: String,
        screen: NSScreen,
        pomodoroCount: Int,
        isAnimatingOut: Binding<Bool>,
        showContent: Bool = true
    ) {
        self.technique = technique
        self.screen = screen
        self.pomodoroCount = pomodoroCount
        self._isAnimatingOut = isAnimatingOut
        self.showContent = showContent
        
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
    
    private func handleEscape() {
        // Ensure UI updates happen on the main thread with animation
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                escapeCount += 1
                if escapeCount >= 3 {
                    handleSkip()
                }
            }
        }
    }
    
    private var content: (title: String, description: String) {
        switch technique {
        case "20-20-20 Rule":
            return (
                "Quick break!",
                "Look 20 feet away for 20 seconds"
            )
        case "Pomodoro Technique":
            if pomodoroCount >= 4 {
                return (
                    "Long Break! 🎉",
                    "Great work on completing 4 sessions!\nTake 30 minutes to recharge"
                )
            } else {
                switch pomodoroCount {
                case 1:
                    return (
                        "Break Time ☕",
                        "Take 5 minutes to recharge.\nStretch, grab a drink, or just chill for a bit!"
                    )
                case 2:
                    return (
                        "You’ve Earned It! 🌿",
                        "Relax those eyes and take a deep breath."
                    )
                case 3:
                    return (
                        "Pause & Refresh 🍵",
                        "Grab a snack or enjoy a quick stroll!"
                    )
                default:
                    return (
                        "Time for a Long Break! 🏖️",
                        "You’ve done amazing work!"
                    )
                }
            }
        case "Custom":
            return (
                "Break time!⏰",
                "Take a moment to unwind. You’ve earned it!"
            )
        default:
            return (
                "Break time!⏰ ",
                "Take a moment to unwind. You’ve earned it!"
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
    
    private var formattedCurrentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: currentTime)
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
            
            // Add the key event handler
            KeyEventHandlingView(onEscape: handleEscape)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)
            
            if showContent {
                // Content with smoother animation
                VStack(spacing: 32) {
                    // Current time at the top
                    Text(formattedCurrentTime)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 64)
                    
                    Spacer()
                    
                    // Title
                    Text(content.title)
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    
                    // Description
                    Text(content.description)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    // Timer
                    Text(formattedTime)
                        .font(.system(size: 64, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .transition(.scale.combined(with: .opacity))
                    
                    Spacer()
                    
                    // Skip button
                    Button(action: handleSkip) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.2))
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    // Escape key counter text
                    if escapeCount > 0 && escapeCount < 3 {
                        Text("Press ⎋ esc \(3 - escapeCount) more time\(3 - escapeCount == 1 ? "" : "s") to skip")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 8)
                    } else {
                        Text(" Press ⎋ esc 3 times to skip")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 8)
                    }
                    
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 32)
                .opacity(isAppearing ? 1 : 0)
                .blur(radius: isAppearing ? 0 : 10)
                .scaleEffect(isAppearing ? 1 : 0.9)
            }
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // Break duration is over
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    appDelegate.handleBreakComplete()  // New method to handle break completion
                }
                handleSkip()
            }
        }
        .onReceive(timeTimer) { _ in
            currentTime = Date()
        }
        .onAppear {
            wallpaperImage = getSystemWallpaper()
            withAnimation(
                .spring(
                    response: 0.6,
                    dampingFraction: 0.8,
                    blendDuration: 0
                )
            ) {
                isAppearing = true
            }
            
            // Ensure internal display window is activated
            DispatchQueue.main.async {
                let isInternalDisplay = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber") as NSDeviceDescriptionKey] as? CGDirectDisplayID == CGMainDisplayID()
                
                if isInternalDisplay {
                    if let window = NSApplication.shared.windows.first(where: { $0.screen == screen }) {
                        window.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
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

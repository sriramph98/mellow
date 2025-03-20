import SwiftUI
import Combine
import IOKit.pwr_mgt

public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let alpha: CGFloat
    
    init(
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode,
        alpha: CGFloat = 1.0
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.alpha = alpha
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
        
        // Add semi-transparent black background
        if let layer = visualEffectView.layer {
            layer.backgroundColor = NSColor.black.withAlphaComponent(alpha).cgColor
        }
        
        return visualEffectView
    }
    
    public func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        if let layer = visualEffectView.layer {
            layer.backgroundColor = NSColor.black.withAlphaComponent(alpha).cgColor
        }
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

// Add this class at the top level of the file
class ScreenSaverManager: ObservableObject {
    var assertionID: IOPMAssertionID = 0
    
    func preventScreenSaver() {
        var assertionID = self.assertionID
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Mellow Break in Progress" as CFString,
            &assertionID
        )
        
        if success == kIOReturnSuccess {
            self.assertionID = assertionID
        }
    }
    
    func allowScreenSaver() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
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
    var testMode: Bool = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let progressTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var progress: Double = 1.0
    @State private var wallpaperImage: NSImage?
    @State private var escapeCount = 0
    @State private var currentTime = Date()
    private let timeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @StateObject var screenSaverManager = ScreenSaverManager()
    @State private var showingSkipConfirmation = false
    
    init(
        technique: String,
        screen: NSScreen,
        pomodoroCount: Int,
        isAnimatingOut: Binding<Bool>,
        showContent: Bool = true,
        testMode: Bool = false
    ) {
        self.technique = technique
        self.screen = screen
        self.pomodoroCount = pomodoroCount
        self._isAnimatingOut = isAnimatingOut
        self.showContent = showContent
        self.testMode = testMode
        
        let duration: TimeInterval
        if testMode {
            duration = 10 // 10 second timeout for test mode
        } else {
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
        }
        self._timeRemaining = State(initialValue: duration)
    }
    
    // Get screen width for relative sizing
    private var screenWidth: CGFloat {
        NSScreen.main?.frame.width ?? 1440
    }
    
    private func handleSkip(fromButton: Bool = false) {
        if fromButton {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                showingSkipConfirmation = true
                escapeCount = 0 // Reset escape count when showing skip confirmation
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isAnimatingOut = true
                isAppearing = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    appDelegate.skipBreak()
                }
            }
        }
    }
    
    private func confirmSkip() {
        // Trigger fade out animation first
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                escapeCount += 1
                if escapeCount >= 3 {
                    handleSkip(fromButton: false)  // Direct skip for ESC
                }
            }
        }
    }
    
    private var content: (emoji: String, title: String, description: String) {
        switch technique {
        case "20-20-20 Rule":
            return (
                "👀",
                "Quick break!",
                "Look 20 feet away for 20 seconds"
            )
        case "Pomodoro Technique":
            if pomodoroCount >= 4 {
                return (
                    "🎉",
                    "Long Break!",
                    "Great work on completing 4 sessions!\nTake 30 minutes to recharge"
                )
            } else {
                switch pomodoroCount {
                case 1:
                    return (
                        "☕",
                        "Break Time",
                        "Take 5 minutes to recharge.\nStretch, grab a drink, or just chill for a bit!"
                    )
                case 2:
                    return (
                        "🌿",
                        "You've Earned It!",
                        "Relax those eyes and take a deep breath."
                    )
                case 3:
                    return (
                        "🍵",
                        "Pause & Refresh",
                        "Grab a snack or enjoy a quick stroll!"
                    )
                default:
                    return (
                        "🏖️",
                        "Time for a Long Break!",
                        "You've done amazing work!"
                    )
                }
            }
        case "Custom":
            return (
                "⏰",
                "Break time!",
                "Take a moment to unwind. You've earned it!"
            )
        default:
            return (
                "⏰",
                "Break time!",
                "Take a moment to unwind. You've earned it!"
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
    
    private var pomodoroCircles: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < pomodoroCount ? Color.white : Color.white.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 16)
    }
    
    var body: some View {
        ZStack {
            // Base blur layer
            VisualEffectView(
                material: .fullScreenUI,
                blendingMode: .behindWindow,
                alpha: 0.5
            )
            
            // Additional blur for depth
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .withinWindow,
                alpha: 0.3
            )
            
            // Add KeyEventHandlingView to capture escape key events
            KeyEventHandlingView(onEscape: handleEscape)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if showContent {
                VStack(spacing: 32) {
                    // Current time - always visible
                    Text(formattedCurrentTime)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 64)
                    
                    Spacer()
                    
                    // Conditional content based on skip confirmation
                    Group {
                        if showingSkipConfirmation {
                            // Skip confirmation content
                            Text("🤔")
                                .font(.system(size: 64))
                                .padding(.bottom, -16)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            
                            Text("Skip this break?")
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            
                            Text("Your eyes deserve this moment of rest")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            // Original content
                            Text(content.emoji)
                                .font(.system(size: 64))
                                .padding(.bottom, -16)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            
                            Text(content.title)
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(8)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            
                            Text(content.description)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineSpacing(8)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    
                    // Pomodoro circles - always visible if applicable
                    if technique == "Pomodoro Technique" {
                        pomodoroCircles
                    }
                    
                    // Timer - always visible
                    Text(formattedTime)
                        .font(.system(size: 64, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    // Bottom buttons with transitions
                    Group {
                        if showingSkipConfirmation {
                            // Skip confirmation buttons
                            HStack(spacing: 16) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        showingSkipConfirmation = false
                                        escapeCount = 0 // Reset escape count when continuing the break
                                    }
                                }) {
                                    Text("Continue Break")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Capsule().fill(.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                                
                                Button(action: confirmSkip) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "forward")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Skip")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        } else {
                            // Original skip button and ESC text
                            Button(action: { handleSkip(fromButton: true) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "forward")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Skip")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(.white.opacity(0.2)))
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                            
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
                        }
                    }
                    
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 32)
                .opacity(isAppearing ? 1 : 0)
                .blur(radius: isAppearing ? 0 : 10)
                .scaleEffect(isAppearing ? 1 : 0.95)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { _ in
            if testMode {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                }
                if timeRemaining <= 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isAnimatingOut = true
                        isAppearing = false
                    }
                }
            } else {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    handleSkip(fromButton: false)  // Just skip the break when timer ends
                }
            }
        }
        .onReceive(timeTimer) { _ in
            currentTime = Date()
        }
        .onReceive(progressTimer) { _ in
            if testMode {
                withAnimation(.linear(duration: 0.1)) {
                    progress = max(0, Double(timeRemaining) / 5.0)
                }
            }
        }
        .onAppear {
            progress = 1.0
            timeRemaining = testMode ? 10 : timeRemaining
            isAppearing = false
            
            withAnimation(
                .spring(
                    response: 0.3,
                    dampingFraction: 0.65,
                    blendDuration: 0
                )
            ) {
                isAppearing = true
            }
            
            wallpaperImage = getSystemWallpaper()
            
            // Only prevent screen saver if this is not a test mode
            if !testMode {
                screenSaverManager.preventScreenSaver()
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
        .onDisappear {
            // Always allow screen saver when view disappears
            screenSaverManager.allowScreenSaver()
        }
        .opacity(isAppearing ? 1 : 0)
        .onChange(of: isAnimatingOut) { oldValue, newValue in
            if newValue {
                // Allow screen saver when view is animating out
                screenSaverManager.allowScreenSaver()
                withAnimation(
                    .spring(
                        response: 0.3,
                        dampingFraction: 0.65,
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

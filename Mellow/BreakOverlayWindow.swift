import Cocoa
import SwiftUI
import Combine
import IOKit.pwr_mgt

class BreakOverlayWindow: NSWindow {
    private var countdownTimer: Timer?
    private var endTime: Date
    var isBlurOnly: Bool = false
    
    // Designated initializer
    init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool, endTime: Date) {
        self.endTime = endTime
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
    }
    
    // Convenience initializer for creating break overlay windows
    convenience init(contentRect: NSRect, screen: NSScreen, technique: String, endTime: Date, onSkip: @escaping () -> Void) {
        // Call the designated initializer
        self.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: true,
            endTime: endTime
        )
        
        // Configure window properties
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))  // Highest possible level
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        
        // Prevent user interactions with the window except for the skip button
        ignoresMouseEvents = false // Need this to be false to allow the skip button to work
        
        // Make sure window is fully opaque
        alphaValue = 1.0
        
        // Check if this is the internal display
        let isInternalDisplay = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber") as NSDeviceDescriptionKey] as? CGDirectDisplayID == CGMainDisplayID()
        
        // Set isBlurOnly flag based on whether this is the internal display
        self.isBlurOnly = !isInternalDisplay
        
        // Create hosting view for the SwiftUI content
        let hostingView = NSHostingView(
            rootView: BreakOverlayView(
                technique: technique,
                screen: screen,
                endTime: endTime,
                onSkip: onSkip
            )
        )
        
        // Set the hosting view as content
        contentView = hostingView
        
        // Ensure window stays on top and covers the screen, including menu bar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        
        // Make the window immovable and prevent resizing
        isMovable = false
        isMovableByWindowBackground = false
        
        // Make sure the window appears above everything
        orderFrontRegardless()
        
        // Start timer to update remaining time and ensure window stays on top
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Check if break is over
            if Date() >= self.endTime {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
            }
            
            // Ensure window stays frontmost and covers the entire screen
            self.orderFrontRegardless()
        }
    }
    
    deinit {
        countdownTimer?.invalidate()
    }
    
    // Override to prevent the window from becoming inactive
    override var canBecomeKey: Bool {
        return !isBlurOnly
    }
    
    override var canBecomeMain: Bool {
        return !isBlurOnly
    }
    
    // Override mouse events to prevent window from being disturbed
    override func mouseDown(with event: NSEvent) {
        // Don't call super to prevent default behavior
        // Only allow clicks on the skip button (handled by SwiftUI)
        // If this is a blur-only window, ignore all mouse events
        if isBlurOnly {
            return
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        // Don't call super to prevent window dragging
        // If this is a blur-only window, ignore all mouse events
        if isBlurOnly {
            return
        }
    }
    
    // Override key events to prevent keyboard interactions
    override func keyDown(with event: NSEvent) {
        // Don't call super to prevent keyboard shortcuts
        // If this is a blur-only window, ignore all key events
        if isBlurOnly {
            return
        }
    }
    
    // Override to prevent window from being moved by any means
    override func performDrag(with event: NSEvent) {
        // Do nothing to prevent dragging
        // If this is a blur-only window, ignore all drag events
        if isBlurOnly {
            return
        }
    }
}

// VisualEffectView wrapper
struct VisualEffectView: NSViewRepresentable {
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
    
    func makeNSView(context: Context) -> NSVisualEffectView {
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
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        if let layer = visualEffectView.layer {
            layer.backgroundColor = NSColor.black.withAlphaComponent(alpha).cgColor
        }
    }
}

// Key event handling view
struct BreakKeyEventHandlingView: NSViewRepresentable {
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> BreakKeyEventHandlingNSView {
        let view = BreakKeyEventHandlingNSView()
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: BreakKeyEventHandlingNSView, context: Context) {
        nsView.onEscape = onEscape
    }
}

class BreakKeyEventHandlingNSView: NSView {
    var onEscape: (() -> Void)?
    private var focusTimer: Timer?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        // Stop existing timer if any
        focusTimer?.invalidate()
        
        guard let window = self.window else { return }
        
        // Check if this is a blur-only window
        let isBlurOnly = (window as? BreakOverlayWindow)?.isBlurOnly ?? false
        
        // Only make the window key if it's not blur-only
        if !isBlurOnly {
            // Become first responder immediately
            window.makeFirstResponder(self)
            
            // Set up a timer to maintain focus
            focusTimer = Timer.scheduledTimer(withTimeInterval:
                0.1, repeats: true) { [weak self] _ in
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

// Screen saver prevention
class BreakScreenSaverManager: ObservableObject {
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

struct BreakOverlayView: View {
    let technique: String
    let screen: NSScreen
    let endTime: Date
    let onSkip: () -> Void
    
    @State private var timeRemaining: TimeInterval = 0
    @State private var isAppearing = false
    @State private var isAnimatingOut = false
    @State private var currentTime = Date()
    @State private var escapeCount = 0
    @State private var showingSkipConfirmation = false
    @StateObject private var screenSaverManager = BreakScreenSaverManager()
    
    // Check if this is the internal display
    private var isInternalDisplay: Bool {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber") as NSDeviceDescriptionKey] as? CGDirectDisplayID == CGMainDisplayID()
    }
    
    // Check if this window is blur-only
    private var isBlurOnly: Bool {
        if let window = NSApplication.shared.windows.first(where: { $0.screen == screen }) as? BreakOverlayWindow {
            return window.isBlurOnly
        }
        return false
    }
    
    // Timers
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Calculate pomodoro count
    private var pomodoroCount: Int {
        if technique == "Pomodoro Technique" {
            // Get the count from AppDelegate
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                return appDelegate.getPomodoroCount()
            }
        }
        return 0
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
                onSkip()
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
            onSkip()
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
            if pomodoroCount == 4 {
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
                        "First Break",
                        "Take 5 minutes to recharge.\nStretch, grab a drink, or just chill for a bit!"
                    )
                case 2:
                    return (
                        "🌿",
                        "Second Break",
                        "You're doing great!\nTake 5 minutes to refresh your mind."
                    )
                case 3:
                    return (
                        "🍵",
                        "Third Break",
                        "Almost there!\nTake 5 minutes to prepare for your final session."
                    )
                default:
                    return (
                        "⏰",
                        "Break Time",
                        "Take 5 minutes to recharge.\nStretch, grab a drink, or just chill for a bit!"
                    )
                }
            }
        case "Custom":
            let duration = UserDefaults.standard.integer(forKey: "breakDuration")
            let minutes = duration / 60
            let seconds = duration % 60
            let timeString = minutes > 0 ? "\(minutes) minutes" : "\(seconds) seconds"
            return (
                "⏰",
                "Break time!",
                "Take \(timeString) to unwind. You've earned it!"
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
            
            // Add KeyEventHandlingView to capture escape key events only on internal display
            if isInternalDisplay && !isBlurOnly {
                BreakKeyEventHandlingView(onEscape: handleEscape)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Only show content on internal display and when not blur-only
            if isInternalDisplay && !isBlurOnly {
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
                                Text("Press ⎋ esc 3 times to skip")
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
            // Update time remaining
            timeRemaining = max(0, endTime.timeIntervalSinceNow)
            
            // Check if timer is up
            if timeRemaining <= 0 {
                handleSkip(fromButton: false)
            }
        }
        .onReceive(timeTimer) { _ in
            currentTime = Date()
        }
        .onAppear {
            // Initialize time remaining
            timeRemaining = max(0, endTime.timeIntervalSinceNow)
            isAppearing = false
            
            // Start appear animation
            withAnimation(
                .spring(
                    response: 0.3,
                    dampingFraction: 0.65,
                    blendDuration: 0
                )
            ) {
                isAppearing = true
            }
            
            // Prevent screen sleep
            screenSaverManager.preventScreenSaver()
        }
        .onDisappear {
            // Allow screen sleep when view disappears
            screenSaverManager.allowScreenSaver()
        }
        .opacity(isAppearing ? 1 : 0)
        .onChange(of: isAnimatingOut) { oldValue, newValue in
            if newValue {
                // Allow screen sleep when view is animating out
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
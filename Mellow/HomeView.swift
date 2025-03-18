import SwiftUI
import AppKit

struct PresetCard: View {
    let title: String
    let isSelected: Bool
    let description: String
    let action: () -> Void
    let isCustom: Bool
    let onModify: (() -> Void)?
    let isDisabled: Bool
    let namespace: Namespace.ID
    let timerState: TimerState
    let isRunning: Bool
    let onStartStop: () -> Void
    let onPauseResume: () -> Void
    @State private var hoverLocation: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var isHovering = false
    @State private var hoverTimer: Timer? = nil
    @State private var isFlipped = false
    @State private var customReminderInterval: Double = 20
    @State private var customBreakDuration: Double = 0.33
    @State private var notificationObserver: NSObjectProtocol? = nil
    
    init(
        title: String,
        isSelected: Bool,
        description: String,
        action: @escaping () -> Void,
        isCustom: Bool = false,
        onModify: (() -> Void)? = nil,
        isDisabled: Bool = false,
        namespace: Namespace.ID,
        timerState: TimerState,
        isRunning: Bool,
        onStartStop: @escaping () -> Void,
        onPauseResume: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.description = description
        self.action = action
        self.isCustom = isCustom
        self.onModify = onModify
        self.isDisabled = isDisabled
        self.namespace = namespace
        self.timerState = timerState
        self.isRunning = isRunning
        self.onStartStop = onStartStop
        self.onPauseResume = onPauseResume
        
        // Initialize custom rule values from UserDefaults
        let savedReminderInterval = UserDefaults.standard.integer(forKey: "reminderInterval")
        let savedBreakDuration = UserDefaults.standard.integer(forKey: "breakDuration")
        
        if savedReminderInterval > 0 {
            _customReminderInterval = State(initialValue: Double(savedReminderInterval) / 60.0)
        }
        
        if savedBreakDuration > 0 {
            _customBreakDuration = State(initialValue: Double(savedBreakDuration) / 60.0)
        }
    }
    
    private var sfSymbol: String {
        switch title {
        case "20-20-20 Rule":
            return "eye.fill"  // Eye symbol for 20-20-20 rule
        case "Pomodoro Technique":
            return "clock.fill"  // Timer for Pomodoro
        case "Custom":
            return "slider.horizontal.below.square.and.square.filled"  // Slider for custom settings
        default:
            return "clock.fill"
        }
    }
    
    private var cardStyle: (background: Color, opacity: Double) {
        if isSelected {
            return (
                .white,
                0.8  // Lighter tint when selected
            )
        } else if isHovering {
            return (
                .white,
                0.4  // Medium hover state (50%)
            )
        } else {
            return (
                .white,
                0.2  // Lower base state (40%)
            )
        }
    }
    
    var body: some View {
        let titleAlignment: Alignment = isRunning ? .center : .leading
        let textAlignment: TextAlignment = isRunning ? .center : .leading
        let textColor = Color.black.opacity(0.6)
        
        // Use a Group to conditionally render either a Button (when not flipped) or a regular view (when flipped)
        return Group {
            if isFlipped {
                // When flipped, use a regular view instead of a button
                GeometryReader { geometry in
                    ZStack {
                        // Back side of the card - Custom Rules Interface
                        customRuleInterface
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: isSelected ? Color.black.opacity(0.2) : (isHovering ? Color.black.opacity(0.15) : Color.clear), 
                            radius: isSelected ? 15 : (isHovering ? 10 : 0), 
                            x: 0, 
                            y: isSelected ? 5 : 3)
                    .contentShape(Rectangle())
                    .zIndex(10) // Increase z-index when flipped
                    .frame(maxWidth: 440, minHeight: 390) // Further reduced for better fit
                    .onHover { hovering in
                        isHovering = hovering && !isDisabled
                        
                        // Reset position when no longer hovering
                        if !hovering {
                            hoverLocation = CGPoint(x: 0.5, y: 0.5)
                            // Invalidate timer when not hovering
                            hoverTimer?.invalidate()
                            hoverTimer = nil
                        } else {
                            // Start timer to track mouse position continuously
                            hoverTimer?.invalidate()
                            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
                                updateHoverLocation(geometry: geometry)
                            }
                        }
                    }
                    .rotation3DEffect(
                        Angle(degrees: 180),
                        axis: (x: 0, y: 1, z: 0)
                    )
                }
            } else {
                // When not flipped, use a button
                Button(action: action) {
                    GeometryReader { geometry in
                        ZStack {
                            // Front side of the card
                            // Main content
                            VStack(spacing: 16) {
                                // Title and description at the top
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(title)
                                        .font(Font.custom("SF Pro Rounded", size: 17).weight(.bold))
                                        .foregroundColor(textColor)
                                        .frame(maxWidth: .infinity, alignment: titleAlignment)
                                    
                                    if !isSelected || !isRunning {
                                        Text(description)
                                            .font(Font.custom("SF Pro Rounded", size: 14).weight(.regular))
                                            .foregroundColor(Color.black.opacity(0.4))  // Set description text opacity to 60%
                                            .lineSpacing(CGFloat(14) * 0.5) // Adjusted line spacing for 13pt font
                                            .fixedSize(horizontal: false, vertical: true)
                                            .multilineTextAlignment(textAlignment)
                                            .frame(maxWidth: .infinity, alignment: titleAlignment)
                                    }
                                }
                                
                                Spacer()
                                
                                // Timer controls and settings button
                                if isSelected {
                                    timerControlsView
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(cardStyle.background.opacity(cardStyle.opacity))
                            }
                            
                            // Unified icon with animation between positions
                            ZStack {
                                // Circle background that fades out when running
                                Circle()
                                    .fill(Color.black.opacity(0.1))
                                    .frame(width: 144, height: 144)
                                    .opacity(isRunning ? 0 : 1) // Fade out circle when running
                                    .scaleEffect(isRunning ? 0.7 : 1) // Scale down circle when running
                                
                                Image(systemName: sfSymbol)
                                    .font(.system(size: 60))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(isRunning ? .black : .white)
                                    .opacity(0.6)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isRunning ? .center : .bottomTrailing)
                            .modifier(IconPathAnimationModifier(isRunning: isRunning, isSelected: isSelected))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: isSelected ? Color.black.opacity(0.2) : (isHovering ? Color.black.opacity(0.15) : Color.clear), 
                                radius: isSelected ? 15 : (isHovering ? 10 : 0), 
                                x: 0, 
                                y: isSelected ? 5 : 3)
                        .contentShape(Rectangle())
                        .zIndex(0)
                        .onHover { hovering in
                            isHovering = hovering && !isDisabled
                            
                            // Reset position when no longer hovering
                            if !hovering {
                                hoverLocation = CGPoint(x: 0.5, y: 0.5)
                                // Invalidate timer when not hovering
                                hoverTimer?.invalidate()
                                hoverTimer = nil
                            } else {
                                // Start timer to track mouse position continuously
                                hoverTimer?.invalidate()
                                hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
                                    updateHoverLocation(geometry: geometry)
                                }
                            }
                        }
                        // Apply 3D effects only when not flipped
                        .rotation3DEffect(
                            Angle(degrees: isHovering ? CGFloat(hoverLocation.x - 0.5) * CGFloat(7) : 0),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .center,
                            anchorZ: 0,
                            perspective: 0.5
                        )
                        .rotation3DEffect(
                            Angle(degrees: isHovering ? CGFloat(hoverLocation.y - 0.5) * CGFloat(-7) : 0),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .center,
                            anchorZ: 0,
                            perspective: 0.5
                        )
                    }
                }
                .buttonStyle(.plain)
                .rotation3DEffect(
                    .zero,
                    axis: (x: 0, y: 1, z: 0)
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .blur(radius: isDisabled ? 1 : 0)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .scaleEffect(isHovering && !isFlipped ? 1.01 : 1.0) // Subtle scale up on hover
        .animation(.smooth(duration: 0.3).delay(0.05), value: isSelected)
        .animation(.smooth(duration: 0.3), value: isDisabled)
        .animation(.smooth(duration: 0.3), value: isRunning)
        .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: isHovering)
        .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: hoverLocation)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
        .onAppear {
            // Add observer for dismissing custom settings
            notificationObserver = NotificationCenter.default.addObserver(forName: .dismissCustomSettings, object: nil, queue: .main) { _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    isFlipped = false
                }
            }
        }
        .onDisappear {
            // Remove observer
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    @ViewBuilder
    private var timerControlsView: some View {
        HStack(spacing: 8) {
            if isRunning {
                // Center align when running
                Spacer()
                
                stopButton
                pauseButton
                
                Spacer()
            } else {
                // For Custom preset, place settings and play button together
                if isCustom {
                    HStack(spacing: 8) {
                        playButton
                        settingsButton
                    }
                    Spacer()
                } else {
                    // For other presets, just show play button
                    playButton
                    Spacer()
                }
            }
        }
        .transition(.asymmetric(
            insertion: .modifier(
                active: AmoebaTrasitionModifier(blur: 15, opacity: 0, scale: 0.7),
                identity: AmoebaTrasitionModifier(blur: 0, opacity: 1, scale: 1.0)
            ),
            removal: .modifier(
                active: AmoebaTrasitionModifier(blur: 15, opacity: 0, scale: 0.7),
                identity: AmoebaTrasitionModifier(blur: 0, opacity: 1, scale: 1.0)
            )
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isRunning)
    }
    
    private var stopButton: some View {
        Button(action: onStartStop) {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .medium))
                Text(timerState.timeString)
                    .font(Font.custom("SF Pro Rounded", size: 16).weight(.medium))
                    .monospacedDigit()
            }
            .foregroundColor(.white)
            .frame(height: 30)
            .padding(.horizontal, 8)
        }
        .buttonStyle(PillButtonStyle(
            customBackground: Color(red: 1, green: 0, blue: 0).opacity(0.8)
        ))
        .transition(.asymmetric(
            insertion: .modifier(
                active: AmoebaTrasitionModifier(blur: 10, opacity: 0, scale: 0.85),
                identity: AmoebaTrasitionModifier(blur: 0, opacity: 1, scale: 1.0)
            ),
            removal: .modifier(
                active: AmoebaTrasitionModifier(blur: 10, opacity: 0, scale: 0.85),
                identity: AmoebaTrasitionModifier(blur: 0, opacity: 1, scale: 1.0)
            )
        ))
        .animation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.02), value: timerState.timeString)
    }
    
    private var pauseButton: some View {
        Button(action: onPauseResume) {
            HStack(spacing: 8) {
                Image(systemName: timerState.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .medium))
                Text(timerState.isPaused ? "Resume" : "Pause")
                    .font(Font.custom("SF Pro Rounded", size: 16).weight(.medium))
            }
            .foregroundColor(.white)
            .frame(height: 30)
            .padding(.horizontal, 8)
        }
        .buttonStyle(PillButtonStyle(
            customBackground: Color(red: 0.3, green: 0.3, blue: 0.3).opacity(0.8)
        ))
        .transition(.asymmetric(
            insertion: .modifier(
                active: AmoebaTrasitionModifier(blur: 10, opacity: 0, scale: 0.85),
                identity: AmoebaTrasitionModifier(blur: 0, opacity: 1, scale: 1.0)
            ),
            removal: .modifier(
                active: AmoebaTrasitionModifier(blur: 10, opacity: 0, scale: 0.85),
                identity: AmoebaTrasitionModifier(blur: 0, opacity: 1, scale: 1.0)
            )
        ))
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.05), value: timerState.isPaused)
    }
    
    private var playButton: some View {
        Button(action: onStartStop) {
            Image(systemName: "play.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 36, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(PillButtonStyle(minWidth: 44))
        .transition(.asymmetric(
            insertion: .modifier(
                active: AmoebaTrasitionModifier(blur: 12, opacity: 0, scale: 1.2),
                identity: AmoebaTrasitionModifier(blur: 0, opacity: 1, scale: 1.0)
            ),
            removal: .modifier(
                active: AmoebaTrasitionModifier(blur: 12, opacity: 0, scale: 1.2),
                identity: AmoebaTrasitionModifier(blur: 0, opacity: 1, scale: 1.0)
            )
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isRunning)
    }
    
    private var settingsButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isFlipped = true
                // Post notification that a card is being flipped
                NotificationCenter.default.post(name: .cardFlipStateChanged, object: nil, userInfo: ["isFlipped": true])
            }
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 36, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(PillButtonStyle(minWidth: 44))
    }
    
    // Function to update hover location
    private func updateHoverLocation(geometry: GeometryProxy) {
        guard isHovering && !isDisabled else { return }
        
        // Get the local mouse position
        if let window = NSApplication.shared.windows.first,
           let view = window.contentView {
            let mousePosition = NSEvent.mouseLocation
            let windowPosition = window.frame.origin
            let viewPosition = view.convert(CGPoint(
                x: mousePosition.x - windowPosition.x,
                y: mousePosition.y - windowPosition.y
            ), from: nil)
            
            // Convert to local coordinates in GeometryReader
            let viewFrame = geometry.frame(in: .global)
            
            // Calculate relative position (0 to 1)
            let x = min(max(0, (viewPosition.x - viewFrame.minX) / viewFrame.width), 1)
            let y = min(max(0, 1 - (viewPosition.y - viewFrame.minY) / viewFrame.height), 1)
            
            hoverLocation = CGPoint(x: x, y: y)
        }
    }
    
    // Add the custom rule interface view
    private var customRuleInterface: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 16) {
                // Header with close button
                HStack {
                    Text("Custom Rule")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.black.opacity(0.8))
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            isFlipped = false
                            // Post notification that card is no longer flipped
                            NotificationCenter.default.post(name: .cardFlipStateChanged, object: nil, userInfo: ["isFlipped": false])
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.black.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .background(Color.black.opacity(0.1))
                
                // Main content in vertical layout
                VStack(alignment: .leading, spacing: 12) {
                    // Break Interval Setting
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Break Interval")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                            
                            Text(formatTime(Int(customReminderInterval * 60)))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.black.opacity(0.5))
                                .monospacedDigit()
                        }
                        
                        Text("How often should we remind you to take a break?")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.black.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        VStack(spacing: 4) {
                            CustomSlider(range: 5...60, value: $customReminderInterval)
                                .frame(height: 20)
                            
                            HStack {
                                Text("5m")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.black.opacity(0.4))
                                
                                Spacer()
                                
                                Text("60m")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.black.opacity(0.4))
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color.black.opacity(0.1))
                    
                    // Break Duration Setting
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Break Duration")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                            
                            Text(formatTime(Int(customBreakDuration * 60)))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.black.opacity(0.5))
                                .monospacedDigit()
                        }
                        
                        Text("How long should each break last?")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.black.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        VStack(spacing: 4) {
                            CustomSlider(range: 0.25...10, value: $customBreakDuration)
                                .frame(height: 20)
                            
                            HStack {
                                Text("15s")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.black.opacity(0.4))
                                
                                Spacer()
                                
                                Text("10m")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.black.opacity(0.4))
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Apply Button
                Button(action: {
                    saveCustomRule()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isFlipped = false
                        // Post notification that card is no longer flipped
                        NotificationCenter.default.post(name: .cardFlipStateChanged, object: nil, userInfo: ["isFlipped": false])
                    }
                }) {
                    Text("Apply")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                        .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.8))
            }
            // Need to rotate the content for proper reading once flipped
            .rotation3DEffect(
                Angle(degrees: 180),
                axis: (x: 0, y: 1, z: 0)
            )
        }
    }
    
    private func formatTime(_ time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "\(seconds)s"
        }
    }
    
    private func saveCustomRule() {
        let reminderInterval = Int(customReminderInterval * 60)
        let breakDuration = Int(customBreakDuration * 60)
        
        UserDefaults.standard.set(reminderInterval, forKey: "reminderInterval")
        UserDefaults.standard.set(breakDuration, forKey: "breakDuration")
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            // Update custom interval directly instead of calling a method
            appDelegate.customInterval = TimeInterval(reminderInterval)
        }
    }
}

// Add this struct to create the organic transition effect
struct AmoebaTrasitionModifier: ViewModifier {
    let blur: CGFloat
    let opacity: CGFloat
    let scale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .opacity(opacity)
            .scaleEffect(scale)
    }
}

struct HomeView: View {
    let timeInterval: TimeInterval
    let onTimeIntervalChange: (TimeInterval) -> Void
    @StateObject private var timerState: TimerState
    @State private var selectedPreset: String = "20-20-20 Rule"
    @State private var isRunning = false
    @State private var isFooterVisible = false
    @State private var isContentVisible = false
    @State private var isModalPresented = false
    @State private var isAnyCardFlipped = false
    @State private var notificationObserver: NSObjectProtocol? = nil
    @State private var showSettings = false
    @Namespace private var animation
    
    init(
        timeInterval: TimeInterval,
        timerState: TimerState,
        onTimeIntervalChange: @escaping (TimeInterval) -> Void
    ) {
        self.timeInterval = timeInterval
        self._timerState = StateObject(wrappedValue: timerState)
        self.onTimeIntervalChange = onTimeIntervalChange
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                // Main content group (everything except footer)
                VStack(spacing: 16) {
                    // App Header
                    HStack(spacing: 12) {
                        // Commented out logo image
                        /*Image("MellowLogo")
                            .resizable()
                            .frame(width: 48, height: 48)
                        
                        Text("Mellow")
                            .font(Font.custom("SF Pro Rounded", size: 24).weight(.heavy))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black.opacity(0.3))*/
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Preset Cards with 20px spacing
                    HStack(spacing: 20) {
                        // Card container with reduced width
                        VStack {
                            PresetCard(
                                title: "20-20-20 Rule",
                                isSelected: selectedPreset == "20-20-20 Rule",
                                description: "Take a 20-second break every 20 minutes to look at something 20 feet away.",
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedPreset = "20-20-20 Rule"
                                        onTimeIntervalChange(1200)
                                    }
                                },
                                isDisabled: (isRunning && selectedPreset != "20-20-20 Rule") || isAnyCardFlipped,
                                namespace: animation,
                                timerState: timerState,
                                isRunning: isRunning && selectedPreset == "20-20-20 Rule",
                                onStartStop: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        isRunning.toggle()
                                    }
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        if isRunning {
                                            appDelegate.startSelectedTechnique(technique: selectedPreset)
                                        } else {
                                            appDelegate.stopTimer()
                                        }
                                    }
                                },
                                onPauseResume: {
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        appDelegate.togglePauseTimer()
                                    }
                                }
                            )
                        }
                        .frame(width: 280) // Changed from 200 to 280
                        .padding(.vertical, 10) // Added vertical padding
                        
                        VStack {
                            PresetCard(
                                title: "Pomodoro Technique",
                                isSelected: selectedPreset == "Pomodoro Technique",
                                description: "Focus for 25 minutes, then take a 5-minute break to stay productive.",
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedPreset = "Pomodoro Technique"
                                        onTimeIntervalChange(1500)
                                    }
                                },
                                isDisabled: (isRunning && selectedPreset != "Pomodoro Technique") || isAnyCardFlipped,
                                namespace: animation,
                                timerState: timerState,
                                isRunning: isRunning && selectedPreset == "Pomodoro Technique",
                                onStartStop: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        isRunning.toggle()
                                    }
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        if isRunning {
                                            appDelegate.startSelectedTechnique(technique: selectedPreset)
                                        } else {
                                            appDelegate.stopTimer()
                                        }
                                    }
                                },
                                onPauseResume: {
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        appDelegate.togglePauseTimer()
                                    }
                                }
                            )
                        }
                        .frame(width: 280) // Changed from 200 to 280
                        .padding(.vertical, 10) // Added vertical padding
                        
                        VStack {
                            PresetCard(
                                title: "Custom",
                                isSelected: selectedPreset == "Custom",
                                description: "Set your own rules to match your workflow.",
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedPreset = "Custom"
                                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                            onTimeIntervalChange(appDelegate.customInterval)
                                        }
                                    }
                                },
                                isCustom: true,
                                onModify: nil,
                                isDisabled: isRunning && selectedPreset != "Custom",
                                namespace: animation,
                                timerState: timerState,
                                isRunning: isRunning && selectedPreset == "Custom",
                                onStartStop: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        isRunning.toggle()
                                    }
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        if isRunning {
                                            appDelegate.startSelectedTechnique(technique: selectedPreset)
                                        } else {
                                            appDelegate.stopTimer()
                                        }
                                    }
                                },
                                onPauseResume: {
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        appDelegate.togglePauseTimer()
                                    }
                                }
                            )
                        }
                        .frame(width: 280) // Changed from 200 to 280
                        .padding(.vertical, 10) // Added vertical padding
                    }
                    .frame(minHeight: isAnyCardFlipped ? 390 : 320)  // Further reduced to 390 for better fit
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24) // Increased vertical padding further for better spacing
                }
                .blur(radius: isContentVisible ? 0 : 10)
                .opacity(isContentVisible ? 1 : 0)
                .scaleEffect(isContentVisible ? 1 : 0.8)
                
                // Footer section
                HStack {
                    Spacer() // Add spacer at the start
                    
                    // Center - Menu bar info (moved from left)
                    VStack(alignment: .center, spacing: 8) { // Changed alignment to .center
                        HStack(spacing: 8) {
                            Image(systemName: "menubar.arrow.up.rectangle")
                                .font(.system(size: 13))
                                .foregroundColor(.black.opacity(0.6))
                            
                            Text("Mellow lives in the menu bar")
                                .font(Font.custom("SF Pro Rounded", size: 13).weight(.regular))
                                .foregroundColor(.black.opacity(0.6))
                        }
                        
                        Text("Click the icon in the menu to access Mellow")
                            .font(Font.custom("SF Pro Rounded", size: 11).weight(.regular))
                            .foregroundColor(.black.opacity(0.4))
                            .multilineTextAlignment(.center) // Added center text alignment
                    }
                    .frame(maxWidth: .infinity) // Make the VStack take up all available space
                    
                    // Right side - Settings icon (keep this on the right)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showSettings = true
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.black.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                    .help("Open Settings")
                    .tag(1001) // Tag for popover anchoring
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .offset(y: isFooterVisible ? 0 : 100)
                .opacity(isFooterVisible ? 1 : 0)
                .blur(radius: isFooterVisible ? 0 : 10)
            }
            .padding(.top, 12)
            .frame(minWidth: 900)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                ZStack {
                    // Gradient background
                    LinearGradient(
                        gradient: Gradient(stops: [
                            Gradient.Stop(color: Color(hex: "#71C3FF"), location: 0.00),
                            Gradient.Stop(color: Color(hex: "#FFFFFF"), location: 1.00),
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            )
            
            // Overlay for settings
            if showSettings {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showSettings = false
                        }
                    }
                
                SettingsView(onClose: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSettings = false
                    }
                })
                .frame(width: 320, height: 360)
                .background(Color(.windowBackgroundColor))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .onAppear {
            // Animate content first, then footer
            withAnimation(
                .spring(
                    response: 0.6,         // Changed from 0.3 to 0.6
                    dampingFraction: 0.8,  // Changed from 0.5 to 0.8
                    blendDuration: 0
                )
            ) {
                isContentVisible = true
            }
            
            // Slight delay for footer animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(
                    .spring(
                        response: 0.6,     // Changed from 0.3 to 0.6
                        dampingFraction: 0.8,  // Changed from 0.5 to 0.8
                        blendDuration: 0
                    )
                ) {
                    isFooterVisible = true
                }
            }
            
            // Register for card flip state change notifications
            notificationObserver = NotificationCenter.default.addObserver(forName: .cardFlipStateChanged, object: nil, queue: .main) { notification in
                if let isFlipped = notification.userInfo?["isFlipped"] as? Bool {
                    isAnyCardFlipped = isFlipped
                }
            }
        }
        .onDisappear {
            // Remove observer
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        .allowsHitTesting(!isModalPresented)
        .onChange(of: isModalPresented) { oldValue, newValue in
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.homeWindowInteractionDisabled = newValue
            }
        }
        // Add tap gesture to dismiss flipped cards
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // Find and flip back any flipped cards
                    NotificationCenter.default.post(name: .dismissCustomSettings, object: nil)
                }
        )
    }
}

#Preview {
    HomeView(
        timeInterval: 1200,
        timerState: TimerState(),
        onTimeIntervalChange: { _ in }
    )
    .frame(width: 900, height: 600)
}

struct PresetCardPreview: View {
    @Namespace private var namespace
    
    var body: some View {
        PresetCard(
            title: "20-20-20 Rule",
            isSelected: true,
            description: "Every 20 minutes, look 20 feet away for 20 seconds.",
            action: {},
            namespace: namespace,
            timerState: TimerState(),
            isRunning: true,
            onStartStop: {},
            onPauseResume: {}
        )
        .frame(width: 250)
        .background(Color.black.opacity(0.8))
        .padding()
    }
}

#Preview("Preset Card") {
    PresetCardPreview()
}

// Add Color extension for hex color support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Add this struct to create the custom path animation
struct IconPathAnimationModifier: ViewModifier {
    let isRunning: Bool
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        let endY = isSelected ? -40 : -20
        
        return content
            // Use offset for the primary movement
            .offset(x: isRunning ? 0 : 20, y: CGFloat(isRunning ? endY : 20))
            
            // Add subtle rotation for curved motion sensation
            .rotationEffect(Angle(degrees: isRunning ? 0 : 10))
            
            // Scale slightly
            .scaleEffect(isRunning ? 1 : 1.05)
            
            // Add a slight skew effect when not running to enhance the 3D feeling
            .transformEffect(
                isRunning ? .identity : CGAffineTransform(a: 1.0, b: 0, c: 0.05, d: 1.0, tx: 0, ty: 0)
            )
            
            // Custom animation creates the curved path feeling
            .animation(
                .spring(
                    response: 0.6,         // Longer duration
                    dampingFraction: 0.65, // Less dampening for more bounce
                    blendDuration: 0.3
                )
                .delay(isRunning ? 0.05 : 0), // Slight delay when moving to center
                value: isRunning
            )
    }
}

// Add this extension to conditionally apply modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Notification name for dismissing custom settings
extension Notification.Name {
    static let dismissCustomSettings = Notification.Name("dismissCustomSettings")
    static let cardFlipStateChanged = Notification.Name("cardFlipStateChanged")
} 

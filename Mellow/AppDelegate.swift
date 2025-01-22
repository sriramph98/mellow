import Cocoa
import SwiftUI

enum MellowError: LocalizedError {
    case windowCreationFailed
    case soundInitializationFailed
    case timerInitializationFailed
    case invalidTechnique
    case customRuleNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .windowCreationFailed:
            return "Failed to create window"
        case .soundInitializationFailed:
            return "Failed to initialize sound"
        case .timerInitializationFailed:
            return "Failed to start timer"
        case .invalidTechnique:
            return "Invalid break technique"
        case .customRuleNotConfigured:
            return "Custom rule not configured"
        }
    }
}

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class TimerState: ObservableObject {
    @Published var timeString: String = ""
    @Published var isPaused: Bool = false
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var blurWindow: NSWindow?
    var homeWindow: NSWindow?
    var timer: Timer?
    var settingsWindow: NSWindow?
    var customRuleWindow: NSWindow?
    @objc dynamic var timeInterval: TimeInterval = UserDefaults.standard.double(forKey: "breakInterval") {
        didSet {
            UserDefaults.standard.set(timeInterval, forKey: "breakInterval")
            updateMenuBarTitle()
        }
    }
    private var nextBreakTime: Date?
    private var currentTechnique: String?
    private var shortBreakDuration: TimeInterval = 300  // 5 minutes
    private var longBreakDuration: TimeInterval = 1800  // 30 minutes
    private var pomodoroCount: Int = 0
    private var customBreakDuration: TimeInterval {
        TimeInterval(UserDefaults.standard.integer(forKey: "breakDuration"))
    }
    private var breakSound: NSSound?
    private var lastUsedInterval: TimeInterval?
    private var lastUsedBreakDuration: TimeInterval?
    private let timerState = TimerState()
    @Published private var isAnimatingOut = false
    private var blurWindows: [NSWindow] = []  // Add array to track all blur windows
    private var settingsOverlayWindow: NSWindow?
    private var settingsBlurView: NSView?
    private var customRuleOverlayView: NSView?
    @AppStorage("customInterval") var customInterval: TimeInterval = 1200 // Default 20 minutes
    @AppStorage("isCustomRuleConfigured") var isCustomRuleConfigured: Bool = false
    private var pausedTimeRemaining: TimeInterval?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // Remove/comment any notification permission requests here
        // UNUserNotificationCenter.current().requestAuthorization...
        
        setupMinimalMainMenu()
        
        if UserDefaults.standard.double(forKey: "breakInterval") == 0 {
            UserDefaults.standard.set(1200, forKey: "breakInterval")
        }
        
        createAndShowHomeWindow()
        setupMenuBar()
        
        DispatchQueue.main.async { [weak self] in
            NSApplication.shared.activate(ignoringOtherApps: true)
            self?.homeWindow?.makeKeyAndOrderFront(nil)
        }
    }
    
    private func setupMinimalMainMenu() {
        let mainMenu = NSMenu()
        
        // Application Menu (Mellow)
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // About Mellow
        appMenu.addItem(NSMenuItem(title: "About Mellow", action: #selector(showAboutPanel), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        
        // Main actions
        appMenu.addItem(NSMenuItem(title: "Open Mellow", action: #selector(showHomeScreen), keyEquivalent: "o"))
        appMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        
        // Share Feedback
        appMenu.addItem(NSMenuItem(title: "Share Feedback", action: #selector(shareFeedback), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        
        // Quit
        appMenu.addItem(NSMenuItem(title: "Quit Mellow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc private func shareFeedback() {
        NSWorkspace.shared.open(URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSfQ1g2pwtErgAGpbmlxqJpPM7Yc0nDmAERLyBZzZHn3zSHQVw/viewform?usp=sharing")!)
    }
    
    private func createAndShowHomeWindow() {
        let homeView = HomeView(
            timeInterval: timeInterval,
            timerState: timerState,
            onTimeIntervalChange: { [weak self] newValue in
                self?.timeInterval = newValue
            }
        )
        
        homeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 100),
            styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Add beta tag to title
        let betaTag = NSTextField(labelWithString: "BETA")
        betaTag.font = .systemFont(ofSize: 10, weight: .medium)
        betaTag.textColor = .white
        betaTag.backgroundColor = NSColor(white: 1.0, alpha: 0.2)
        betaTag.isBezeled = false
        betaTag.isEditable = false
        betaTag.alignment = .center
        betaTag.frame = NSRect(x: homeWindow!.frame.width - 60, y: homeWindow!.frame.height - 28, width: 40, height: 18)
        betaTag.layer?.cornerRadius = 4
        betaTag.layer?.masksToBounds = true
        
        if let titlebarView = homeWindow?.standardWindowButton(.closeButton)?.superview?.superview {
            titlebarView.addSubview(betaTag)
        }
        
        // Configure window for appearance modes
        homeWindow?.appearance = NSAppearance(named: .darkAqua)
        homeWindow?.isMovableByWindowBackground = true
        homeWindow?.titlebarAppearsTransparent = true
        homeWindow?.titleVisibility = .hidden
        homeWindow?.backgroundColor = .clear
        homeWindow?.isOpaque = false
        homeWindow?.hasShadow = true
        
        // Create container view with size fitting
        let containerView = NSView(frame: .zero)
        containerView.autoresizingMask = [.width, .height]
        
        // Create visual effect view with proper materials
        let visualEffect = NSVisualEffectView(frame: containerView.bounds)
        visualEffect.material = .fullScreenUI
        visualEffect.blendingMode = .withinWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.appearance = NSAppearance(named: .darkAqua)
        
        // Configure background for both modes
        visualEffect.autoresizingMask = [.width, .height]
        if let layer = visualEffect.layer {
            layer.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        }
        
        // Add a second visual effect for additional blur if needed
        let secondaryBlur = NSVisualEffectView(frame: containerView.bounds)
        secondaryBlur.material = .hudWindow
        secondaryBlur.blendingMode = .withinWindow
        secondaryBlur.state = .active
        secondaryBlur.autoresizingMask = [.width, .height]
        visualEffect.addSubview(secondaryBlur)
        
        containerView.addSubview(visualEffect)
        
        // Create and add SwiftUI hosting view
        let hostingView = NSHostingView(rootView: homeView)
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        // Ensure hosting view is transparent to show blur
        if let layer = hostingView.layer {
            layer.backgroundColor = .clear
        }
        
        containerView.addSubview(hostingView)
        
        homeWindow?.contentView = containerView
        homeWindow?.setContentSize(hostingView.fittingSize)
        homeWindow?.center()
        homeWindow?.isReleasedWhenClosed = false
        homeWindow?.delegate = self
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Configure menu bar icon
            if let menuBarIcon = NSImage(named: "menuBarIcon") {
                menuBarIcon.isTemplate = true
                menuBarIcon.size = NSSize(width: 18, height: 18)
                button.image = menuBarIcon
                button.imagePosition = .imageLeft
                button.imageScaling = .scaleProportionallyDown
            }
            
            // Set up click action
            button.target = self
            button.action = #selector(menuBarButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        updateMenuBarTitle()
    }
    
    @objc private func menuBarButtonClicked() {
        guard let button = statusItem?.button else { return }
        
        let menu = NSMenu()
        
        // Primary actions
        menu.addItem(NSMenuItem(title: "Open Mellow", action: #selector(showHomeScreen), keyEquivalent: ""))
        
        // Timer-dependent actions
        if timer != nil || timerState.isPaused {
            menu.addItem(NSMenuItem.separator())
            
            if timerState.isPaused {
                // When paused, show Resume and Stop
                menu.addItem(NSMenuItem(title: "Resume Timer", action: #selector(togglePauseFromMenu), keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "Stop Timer", action: #selector(stopTimerFromMenu), keyEquivalent: ""))
            } else {
                // When running, show Pause and Stop
                menu.addItem(NSMenuItem(title: "Pause Timer", action: #selector(togglePauseFromMenu), keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "Stop Timer", action: #selector(stopTimerFromMenu), keyEquivalent: ""))
                
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "Take Break Now", action: #selector(takeBreakNow), keyEquivalent: ""))
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings and About
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Mellow", action: #selector(showAboutPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Share Feedback", action: #selector(shareFeedback), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // Show menu
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil  // Clear menu after showing
    }
    
    @objc private func togglePauseFromMenu() {
        togglePauseTimer()
    }
    
    @objc private func stopTimerFromMenu() {
        stopTimer()
    }
    
    @objc private func resetTimerFromMenu() {
        if let currentTechnique = currentTechnique {
            stopTimer()
            startSelectedTechnique(technique: currentTechnique, isReset: true)
        }
    }
    
    private func updateMenuBarTitle() {
        if let button = statusItem?.button {
            if timer != nil || timerState.isPaused {
                if timerState.isPaused {
                    if let remaining = pausedTimeRemaining {
                        let minutes = Int(remaining) / 60
                        let seconds = Int(remaining) % 60
                        
                        // Show only seconds if less than 1 minute
                        if minutes == 0 {
                            timerState.timeString = String(format: "%ds", seconds)
                            button.title = String(format: " ⏸ %ds", seconds)
                        } else {
                            timerState.timeString = String(format: "%d:%02d", minutes, seconds)
                            button.title = String(format: " ⏸ %d:%02d", minutes, seconds)
                        }
                    }
                } else if let nextBreak = nextBreakTime {
                    let timeRemaining = nextBreak.timeIntervalSinceNow
                    if timeRemaining > 0 {
                        let minutes = Int(timeRemaining) / 60
                        let seconds = Int(timeRemaining) % 60
                        
                        // Show only seconds if less than 1 minute
                        if minutes == 0 {
                            timerState.timeString = String(format: "%ds", seconds)
                            button.title = String(format: " %ds", seconds)
                        } else {
                            timerState.timeString = String(format: "%d:%02d", minutes, seconds)
                            button.title = String(format: " %d:%02d", minutes, seconds)
                        }
                    } else {
                        timerState.timeString = "0"
                        button.title = " 0"
                    }
                }
            } else {
                timerState.timeString = ""
                button.title = ""
                
                // Reset to custom icon
                if let menuBarIcon = NSImage(named: "menuBarIcon") {
                    menuBarIcon.isTemplate = true
                    menuBarIcon.size = NSSize(width: 18, height: 18)
                    button.image = menuBarIcon
                    button.imageScaling = .scaleProportionallyDown
                }
            }
        }
    }
    
    @objc private func skipNextBreak() {
        do {
            try startTimer()
        } catch {
            handleError(error)
        }
    }
    
    @objc private func takeBreakNow() {
        showBlurScreen(forTechnique: currentTechnique)
    }
    
    private func startTimer() throws {
        timer?.invalidate()
        
        guard timeInterval > 0 else {
            throw MellowError.timerInitializationFailed
        }
        
        nextBreakTime = Date().addingTimeInterval(timeInterval)
        timerState.isPaused = false
        pausedTimeRemaining = nil
        
        timer = Timer(fire: Date(), interval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        // Set initial value in MM:SS format
        let initialMinutes = Int(timeInterval) / 60
        let initialSeconds = Int(timeInterval) % 60
        updateTimeString(String(format: "%d:%02d", initialMinutes, initialSeconds))
        
        RunLoop.main.add(timer!, forMode: .common)
        updateMainMenu()
    }
    
    @objc private func showHomeScreen() {
        // Only set activation policy if window isn't visible
        if homeWindow?.isVisible != true {
            NSApp.setActivationPolicy(.regular)
        }
        
        if homeWindow == nil {
            createAndShowHomeWindow()
        }
        
        // Ensure window is visible and app is active
        if let window = homeWindow {
            if window.isVisible {
                window.orderFront(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
        }
        
        // Activate app and bring to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showBlurScreen(forTechnique technique: String? = nil) {
        do {
            // Check if overlay is enabled
            guard UserDefaults.standard.bool(forKey: "showOverlay") else { return }
            
            guard blurWindow == nil else { return }
            isAnimatingOut = false
            blurWindows.removeAll()
            
            // Get the current count
            let currentCount = pomodoroCount
            
            // Create blur windows for each screen
            for screen in NSScreen.screens {
                let window = try createBlurWindow(frame: screen.frame)
                
                // Check if this is the internal display
                let isInternalDisplay = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber") as NSDeviceDescriptionKey] as? CGDirectDisplayID == CGMainDisplayID()
                
                let blurView = BlurView(
                    technique: technique ?? currentTechnique ?? "Custom",
                    screen: screen,
                    pomodoroCount: currentCount,
                    isAnimatingOut: .init(
                        get: { self.isAnimatingOut },
                        set: { self.isAnimatingOut = $0 }
                    ),
                    showContent: isInternalDisplay  // Show content only on internal display
                )
                window.contentView = NSHostingView(rootView: blurView)
                window.makeKeyAndOrderFront(nil)
                
                blurWindows.append(window)
                
                if blurWindow == nil {
                    blurWindow = window
                }
            }
            
            // Handle sound and notifications
            if UserDefaults.standard.bool(forKey: "playSound") {
                try playBreakSound()
            }
            
        } catch {
            handleError(error)
        }
    }
    
    private func createBlurWindow(frame: NSRect) throws -> NSWindow {
        let window = KeyableWindow(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Prevent system sleep during blur view
        window.level = .screenSaver
        
        return window
    }
    
    private func playBreakSound() throws {
        if breakSound == nil {
            guard let sound = NSSound(named: "Glass") else {
                throw MellowError.soundInitializationFailed
            }
            breakSound = sound
        }
        breakSound?.play()
    }
    
    private func getDismissalDuration(for technique: String) throws -> TimeInterval {
        switch technique {
        case "20-20-20 Rule":
            return 20
        case "Pomodoro Technique":
            // After 4 pomodoros, take a long break (30 minutes)
            if pomodoroCount == 4 {
                return longBreakDuration  // 30 minutes
            }
            return shortBreakDuration  // 5 minutes
        case "Custom":
            let duration = TimeInterval(UserDefaults.standard.integer(forKey: "breakDuration"))
            guard duration > 0 else { throw MellowError.customRuleNotConfigured }
            return duration
        default:
            throw MellowError.invalidTechnique
        }
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func dismissBlurScreen() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Get all blur windows
            let blurWindows = NSApplication.shared.windows
                .filter { $0 is KeyableWindow && $0 != self.homeWindow }
                as? [KeyableWindow] ?? []
            
            // First, animate all views simultaneously
            for window in blurWindows {
                if let hostingView = window.contentView as? NSHostingView<BlurView> {
                    withAnimation(.easeOut(duration: 0.3)) {
                        hostingView.rootView.isAppearing = false
                    }
                }
            }
            
            // Then dismiss all windows after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                for window in blurWindows {
                    window.orderOut(nil)
                }
                
                self.blurWindow = nil
                self.breakSound?.stop()
                
                // Handle Pomodoro count and start next timer
                if self.currentTechnique == "Pomodoro Technique" {
                    if self.pomodoroCount == 4 {
                        // After long break, reset to 1
                        self.pomodoroCount = 1
                        print("🍅 Long break completed - Starting new cycle at Count: 1/4")
                    } else {
                        // After short break, increment count
                        self.pomodoroCount += 1
                        print("🍅 Break completed - Count: \(self.pomodoroCount)/4")
                    }
                }
                
                // Start the next timer
                do {
                    self.nextBreakTime = Date().addingTimeInterval(self.timeInterval)
                    try self.startTimer()
                } catch {
                    self.handleError(error)
                }
            }
        }
    }
    
    @objc func showSettings() {
        if let homeWindow = homeWindow {
            // Create overlay window
            let settingsView = SettingsView(onClose: { [weak self] in
                self?.closeSettings()
            })
            .environment(\.colorScheme, .dark)
            
            let hostingView = NSHostingView(rootView: settingsView)
            hostingView.setFrameSize(hostingView.fittingSize)  // Size to fit content
            
            let overlayWindow = NSWindow(
                contentRect: hostingView.frame,  // Use hosting view's size
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            overlayWindow.backgroundColor = .clear
            overlayWindow.isOpaque = false
            overlayWindow.hasShadow = true
            overlayWindow.level = .floating
            
            // Add corner radius to window
            overlayWindow.contentView = hostingView
            if let contentView = overlayWindow.contentView {
                contentView.wantsLayer = true
                contentView.layer?.cornerRadius = 12
                contentView.layer?.masksToBounds = true
            }
            
            // Make overlay window move with main window
            homeWindow.addChildWindow(overlayWindow, ordered: .above)
            
            // Position overlay centered on home window
            positionSettingsOverlay(overlayWindow, relativeTo: homeWindow)
            
            // Store reference to overlay window
            settingsOverlayWindow = overlayWindow
            
            // Add simple dimming overlay to home window
            if let contentView = homeWindow.contentView {
                let overlayView = NSView(frame: contentView.bounds)
                overlayView.wantsLayer = true
                
                // Use black with 40% opacity for dark theme
                overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
                
                overlayView.alphaValue = 0
                contentView.addSubview(overlayView)
                
                // Animate overlay in
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    overlayView.animator().alphaValue = 1
                }
                
                // Store reference to overlay view
                settingsBlurView = overlayView
            }
            
            // Show overlay
            overlayWindow.makeKeyAndOrderFront(nil)
        }
    }
    
    private func positionSettingsOverlay(_ overlay: NSWindow, relativeTo parent: NSWindow) {
        let parentFrame = parent.frame
        let overlayFrame = overlay.frame
        let x = parentFrame.origin.x + (parentFrame.width - overlayFrame.width) / 2
        let y = parentFrame.origin.y + (parentFrame.height - overlayFrame.height) / 2
        overlay.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func closeSettings() {
        // Animate overlay view out
        if let overlayView = settingsBlurView {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                overlayView.animator().alphaValue = 0
                
                // Reset opacity of main window content
                if let contentView = homeWindow?.contentView {
                    contentView.animator().alphaValue = 1.0
                }
            } completionHandler: {
                overlayView.removeFromSuperview()
                self.settingsBlurView = nil
                
                // Close and cleanup overlay window
                if let overlay = self.settingsOverlayWindow {
                    self.homeWindow?.removeChildWindow(overlay)
                    overlay.orderOut(nil)
                    self.settingsOverlayWindow = nil
                }
            }
        }
    }
    
    // Add window delegate method to handle main window movement
    func windowDidMove(_ notification: Notification) {
        if let homeWindow = notification.object as? NSWindow,
           homeWindow == self.homeWindow,
           let overlay = settingsOverlayWindow {
            positionSettingsOverlay(overlay, relativeTo: homeWindow)
        }
    }
    
    func showCustomRuleSettings() {
        if let homeWindow = homeWindow {
            let customRuleView = CustomRuleView(
                onSave: { [weak self] newValue in
                    self?.customInterval = newValue
                    self?.isCustomRuleConfigured = true
                    self?.timeInterval = newValue
                    UserDefaults.standard.set(newValue, forKey: "breakInterval")
                    self?.closeCustomRuleSettings()
                },
                onClose: { [weak self] in
                    self?.closeCustomRuleSettings()
                }
            )
            .environment(\.colorScheme, .dark)
            
            let hostingView = NSHostingView(rootView: customRuleView)
            hostingView.setFrameSize(hostingView.fittingSize)
            
            let overlayWindow = NSWindow(
                contentRect: hostingView.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            overlayWindow.backgroundColor = NSColor.clear
            overlayWindow.isOpaque = false
            overlayWindow.hasShadow = true
            overlayWindow.level = NSWindow.Level.floating
            
            overlayWindow.contentView = hostingView
            if let contentView = overlayWindow.contentView {
                contentView.wantsLayer = true
                contentView.layer?.cornerRadius = 12
                contentView.layer?.masksToBounds = true
            }
            
            homeWindow.addChildWindow(overlayWindow, ordered: .above)
            positionSettingsOverlay(overlayWindow, relativeTo: homeWindow)
            
            // Add dimming overlay
            if let contentView = homeWindow.contentView {
                let overlayView = NSView(frame: contentView.bounds)
                overlayView.wantsLayer = true
                overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
                overlayView.alphaValue = 0
                contentView.addSubview(overlayView)
                
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    overlayView.animator().alphaValue = 1
                }
                
                customRuleOverlayView = overlayView
            }
            
            customRuleWindow = overlayWindow
            overlayWindow.makeKeyAndOrderFront(nil)
        }
    }
    
    private func closeCustomRuleSettings() {
        if let overlayView = customRuleOverlayView {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                overlayView.animator().alphaValue = 0
                
                // Reset window opacity
                homeWindow?.animator().alphaValue = 1.0
            } completionHandler: {
                overlayView.removeFromSuperview()
                self.customRuleOverlayView = nil
                
                if let overlay = self.customRuleWindow {
                    self.homeWindow?.removeChildWindow(overlay)
                    overlay.orderOut(nil)
                    self.customRuleWindow = nil
                }
            }
        }
    }
    
    func startSelectedTechnique(technique: String, isReset: Bool = false) {
        do {
            guard !technique.isEmpty else {
                throw MellowError.invalidTechnique
            }
            
            currentTechnique = technique
            
            switch technique {
            case "20-20-20 Rule":
                timeInterval = 1200  // 20 minutes
            case "Pomodoro Technique":
                timeInterval = 1500  // 25 minutes
                // Only set count to 1 when starting fresh (count = 0), not when resetting
                if pomodoroCount == 0 {
                    pomodoroCount = 1
                    print("🍅 Starting Pomodoro - Count: 1/4")
                } else if isReset {
                    print("🍅 Timer reset - Continuing at Count: \(pomodoroCount)/4")
                }
            case "Custom":
                timeInterval = customInterval
            default:
                if let lastInterval = lastUsedInterval,
                   let lastBreakDuration = lastUsedBreakDuration {
                    timeInterval = lastInterval
                    shortBreakDuration = lastBreakDuration
                } else {
                    throw MellowError.invalidTechnique
                }
            }
            
            // Set initial countdown value without starting timer
            nextBreakTime = Date().addingTimeInterval(timeInterval)
            let initialMinutes = Int(timeInterval) / 60
            let initialSeconds = Int(timeInterval) % 60
            timerState.timeString = String(format: "%d:%02d", initialMinutes, initialSeconds)
            
            try startTimer()
            
        } catch {
            handleError(error)
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerState.isPaused = false
        pausedTimeRemaining = nil
        
        // Store current settings before stopping
        if currentTechnique != nil {
            lastUsedInterval = timeInterval
            lastUsedBreakDuration = shortBreakDuration
        }
        
        // Reset Pomodoro count to 0 when stopping
        if pomodoroCount > 0 {
            print("🍅 Timer stopped - Resetting count from \(pomodoroCount) to 0")
            pomodoroCount = 0
        }
        
        // Reset timer state
        nextBreakTime = nil
        breakSound?.stop()
        updateMenuBarTitle()
        updateMainMenu()
    }
    
    // Add this method to handle window closing
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // Add window delegate methods
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Check which window is closing and handle accordingly
        if window == settingsWindow {
            settingsWindow = nil
        } else if window == customRuleWindow {
            customRuleWindow = nil
        }
    }
    
    private func updateTimeString(_ newValue: String) {
        DispatchQueue.main.async {
            self.timerState.timeString = newValue
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == homeWindow {
            homeWindow?.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
            return false
        }
        return true
    }
    
    private func handleWindowClose() {
        // Additional cleanup if needed
    }
    
    // Add this method to handle dock icon clicks
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHomeScreen()
        return true
    }
    
    func skipBreak() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Wait for animation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Close all tracked blur windows
                for window in self.blurWindows {
                    window.orderOut(nil)
                }
                
                self.blurWindows.removeAll()
                self.blurWindow = nil
                self.breakSound?.stop()
                
                // Handle Pomodoro count when skipping break
                if self.currentTechnique == "Pomodoro Technique" {
                    if self.pomodoroCount == 4 {
                        // After long break, reset to 1
                        self.pomodoroCount = 1
                        print("🍅 Long break skipped - Starting new cycle at Count: 1/4")
                    } else {
                        // After short break, increment count
                        self.pomodoroCount += 1
                        print("🍅 Break skipped - Count: \(self.pomodoroCount)/4")
                    }
                }
                
                // Reset and start the timer only if it was running before
                if self.timer != nil {
                    do {
                        self.nextBreakTime = Date().addingTimeInterval(self.timeInterval)
                        try self.startTimer()
                    } catch {
                        self.handleError(error)
                    }
                } else {
                    // Just update the display without starting timer
                    self.updateMenuBarTitle()
                }
            }
        }
    }
    
    @objc private func showAboutPanel() {
        // Store current status item
        let currentStatusItem = statusItem
        
        // Switch to regular activation policy
        NSApp.setActivationPolicy(.regular)
        
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        // Show the about panel
        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                .applicationIcon: NSImage(named: "MellowLogo") ?? NSImage(),
                .applicationName: "Mellow",
                .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                .credits: NSAttributedString(
                    string: "A mindful break reminder for your productivity.",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
            ]
        )
        
        // Find the about panel and observe its closing
        if let aboutPanel = NSApp.windows.first(where: { $0.title == "About Mellow" }) {
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: aboutPanel,
                queue: .main
            ) { [weak self] _ in
                // Only revert to accessory mode if home window is not visible
                if self?.homeWindow?.isVisible != true {
                    NSApp.setActivationPolicy(.accessory)
                    // Restore status item and update menu bar
                    self?.statusItem = currentStatusItem
                    self?.updateMenuBarTitle()
                }
                // Remove the observer
                NotificationCenter.default.removeObserver(self as Any)
            }
        }
    }
    
    func handleBreakComplete() {
        // Play sound if enabled
        if UserDefaults.standard.bool(forKey: "playSound") {
            do {
                try playBreakSound()
            } catch {
                handleError(error)
            }
        }
        
        // Start the next break interval timer
        do {
            nextBreakTime = Date().addingTimeInterval(timeInterval)
            try startTimer()
        } catch {
            handleError(error)
        }
    }
    
    private func updateMainMenu() {
        if let appMenu = NSApp.mainMenu?.items.first?.submenu {
            // Find and update the Take Break Now menu item
            if let breakMenuItem = appMenu.items.first(where: { $0.title == "Take Break Now" }) {
                breakMenuItem.isEnabled = timer != nil
            }
        }
    }
    
    // Add help action methods
    @objc private func showBreakTechniquesHelp() {
        // Show help about break techniques
        NSWorkspace.shared.open(URL(string: "https://github.com/sriramph98/Mellow/wiki/Break-Techniques")!)
    }
    
    @objc private func showMenuBarHelp() {
        // Show help about menu bar controls
        NSWorkspace.shared.open(URL(string: "https://github.com/sriramph98/Mellow/wiki/Menu-Bar-Controls")!)
    }
    
    @objc private func showSettingsHelp() {
        // Show help about settings
        NSWorkspace.shared.open(URL(string: "https://github.com/sriramph98/Mellow/wiki/Settings-Guide")!)
    }
    
    @objc private func checkForUpdates() {
        NSWorkspace.shared.open(URL(string: "macappstore://apps.apple.com/app/id6740374516?mt=12")!)
    }
    
    private func showUpdateAlert(title: String, message: String, hasUpdate: Bool = false) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func togglePauseTimer() {
        if timerState.isPaused {
            // Resume timer
            if let remaining = pausedTimeRemaining {
                nextBreakTime = Date().addingTimeInterval(remaining)
                pausedTimeRemaining = nil
                
                timer = Timer(fire: Date(), interval: 0.5, repeats: true) { [weak self] _ in
                    self?.updateTimer()
                }
                RunLoop.main.add(timer!, forMode: .common)
            }
        } else {
            // Pause timer
            timer?.invalidate()
            timer = nil
            
            if let nextBreak = nextBreakTime {
                pausedTimeRemaining = nextBreak.timeIntervalSinceNow
            }
        }
        
        timerState.isPaused.toggle()
        updateMenuBarTitle()
    }
    
    private func updateTimer() {
        guard let nextBreak = nextBreakTime else { return }
        
        let timeRemaining = nextBreak.timeIntervalSinceNow
        
        if timeRemaining > 0 {
            let minutes = Int(timeRemaining) / 60
            let seconds = Int(timeRemaining) % 60
            
            // Show overlay when 10 seconds remaining
            if timeRemaining <= 10 && blurWindow == nil && !timerState.isPaused {
                showTestBlurScreen()
            }
            
            // Show only seconds if less than 1 minute
            if minutes == 0 {
                timerState.timeString = String(format: "%ds", seconds)
                if let button = statusItem?.button {
                    button.title = String(format: " %ds", seconds)
                }
            } else {
                timerState.timeString = String(format: "%d:%02d", minutes, seconds)
                if let button = statusItem?.button {
                    button.title = String(format: " %d:%02d", minutes, seconds)
                }
            }
        } else {
            timerState.timeString = "0"
            if let button = statusItem?.button {
                button.title = " 0"
            }
            
            showBlurScreen(forTechnique: currentTechnique)
            nextBreakTime = Date().addingTimeInterval(timeInterval)
        }
    }
    
    func showTestBlurScreen() {
        do {
            // Check if overlay is enabled
            guard UserDefaults.standard.bool(forKey: "showOverlay") else { return }
            
            // Clean up any existing windows first
            blurWindow?.orderOut(nil)
            blurWindow = nil
            blurWindows.forEach { $0.orderOut(nil) }
            blurWindows.removeAll()
            
            // Reset animation state
            isAnimatingOut = false
            
            // Only create window for built-in display
            if let screen = NSScreen.screens.first(where: { screen in
                screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber") as NSDeviceDescriptionKey] as? CGDirectDisplayID == CGMainDisplayID()
            }) {
                // Get menu bar height and add padding
                let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 24
                let topPadding: CGFloat = 16 // Space below menu bar
                
                // Create window with dynamic size
                let window = try createBlurWindow(frame: .zero)
                
                // Configure window
                window.level = .floating
                window.isMovable = false
                window.isMovableByWindowBackground = false
                window.hasShadow = true
                window.backgroundColor = .clear
                
                let overlayView = OverlayView(
                    technique: currentTechnique ?? "Custom",
                    isAnimatingOut: .init(
                        get: { self.isAnimatingOut },
                        set: { [weak self] newValue in 
                            self?.isAnimatingOut = newValue
                            if newValue {
                                // Clear the window references after animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                    self?.blurWindow?.orderOut(nil)
                                    self?.blurWindow = nil
                                    self?.blurWindows.forEach { $0.orderOut(nil) }
                                    self?.blurWindows.removeAll()
                                }
                            }
                        }
                    ),
                    onComplete: { [weak self] in
                        // Show the blur view for the selected technique
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            if let technique = self?.currentTechnique {
                                self?.showBlurScreen(forTechnique: technique)
                            }
                        }
                    }
                )
                
                // Create hosting view and size window to fit content
                let hostingView = NSHostingView(rootView: overlayView)
                window.contentView = hostingView
                hostingView.setFrameSize(hostingView.fittingSize)
                window.setContentSize(hostingView.fittingSize)
                
                // Position window
                let windowX = screen.frame.maxX - window.frame.width - 20
                let windowY = screen.frame.maxY - window.frame.height - (menuBarHeight + topPadding)
                window.setFrameOrigin(NSPoint(x: windowX, y: windowY))
                
                window.makeKeyAndOrderFront(nil)
                
                blurWindows.append(window)
                blurWindow = window
            }
            
        } catch {
            handleError(error)
        }
    }
}

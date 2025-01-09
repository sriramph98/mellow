import Cocoa
import SwiftUI
import UserNotifications

enum UnwindError: LocalizedError {
    case windowCreationFailed
    case soundInitializationFailed
    case timerInitializationFailed
    case invalidTechnique
    case notificationPermissionDenied
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
        case .notificationPermissionDenied:
            return "Notification permission denied"
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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        setupMainMenu()
        
        // Set default interval if not set
        if UserDefaults.standard.double(forKey: "breakInterval") == 0 {
            UserDefaults.standard.set(1200, forKey: "breakInterval")
        }
        
        // Create the SwiftUI window first
        createAndShowHomeWindow()
        
        setupNotifications()
        setupMenuBar()
        
        // Ensure app is active and window is front
        DispatchQueue.main.async { [weak self] in
        NSApplication.shared.activate(ignoringOtherApps: true)
            self?.homeWindow?.makeKeyAndOrderFront(nil)
        }
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        
        // Application Menu (main menu bar)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        let appName = ProcessInfo.processInfo.processName
        
        // About menu item
        appMenu.addItem(NSMenuItem(title: "About \(appName)", action: #selector(showAboutPanel), keyEquivalent: ""))
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Open Unwind menu item
        appMenu.addItem(NSMenuItem(title: "Open Unwind", action: #selector(showHomeScreen), keyEquivalent: "o"))
        
        // Settings menu item
        appMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Quit menu item
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        NSApp.mainMenu = mainMenu
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
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.appearance = NSAppearance(named: .darkAqua)  // Force dark appearance
        
        // Configure background for both modes
        visualEffect.autoresizingMask = [.width, .height]
        if let layer = visualEffect.layer {
            layer.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        }
        
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
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                self.handleError(error)
                return
            }
            
            if !granted {
                self.handleError(UnwindError.notificationPermissionDenied)
            }
        }
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
        
        // Break control only
        menu.addItem(NSMenuItem(title: "Take Break Now", action: #selector(takeBreakNow), keyEquivalent: ""))
        
        // Show menu
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil  // Clear menu after showing
    }
    
    private func updateMenuBarTitle() {
        if let button = statusItem?.button {
            if timer != nil, let nextBreak = nextBreakTime {
                let timeRemaining = nextBreak.timeIntervalSinceNow
                if timeRemaining > 0 {
                    let minutes = Int(timeRemaining) / 60
                    let seconds = Int(timeRemaining) % 60
                    
                    // Show seconds when under a minute
                    if minutes == 0 {
                        timerState.timeString = String(format: "%ds", seconds)
                        button.title = " \(seconds)s"
                    } else {
                        timerState.timeString = String(format: "%d:%02d", minutes, seconds)
                        button.title = " \(minutes)m"
                    }
                } else {
                    timerState.timeString = "0:00"
                    button.title = " 0s"
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
            throw UnwindError.timerInitializationFailed
        }
        
        nextBreakTime = Date().addingTimeInterval(timeInterval)
        
        timer = Timer(fire: Date(), interval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if let nextBreak = self.nextBreakTime {
                let timeRemaining = nextBreak.timeIntervalSinceNow
                
                if timeRemaining > 0 {
                    let minutes = Int(timeRemaining) / 60
                    let seconds = Int(timeRemaining) % 60
                    
                    // Show seconds when under a minute
                    if minutes == 0 {
                        self.updateTimeString(String(format: "%ds", seconds))
                        if let button = self.statusItem?.button {
                            button.title = " \(seconds)s"
                        }
                    } else {
                        self.updateTimeString(String(format: "%d:%02d", minutes, seconds))
                        if let button = self.statusItem?.button {
                            button.title = " \(minutes)m"
                        }
                    }
                } else {
                    self.updateTimeString("0s")
                    if let button = self.statusItem?.button {
                        button.title = " 0s"
                    }
                    
                    self.showBlurScreen(forTechnique: self.currentTechnique)
                    self.nextBreakTime = Date().addingTimeInterval(self.timeInterval)
                }
            }
        }
        
        // Set initial value
        let initialMinutes = Int(timeInterval) / 60
        let initialSeconds = Int(timeInterval) % 60
        if initialMinutes == 0 {
            updateTimeString(String(format: "%ds", initialSeconds))
        } else {
            updateTimeString(String(format: "%d:%02d", initialMinutes, initialSeconds))
        }
        
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    @objc private func showHomeScreen() {
        NSApp.setActivationPolicy(.regular)
        
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
            guard blurWindow == nil else { return }
            isAnimatingOut = false
            blurWindows.removeAll()
            
            // Create blur windows without starting timer
            for screen in NSScreen.screens {
                let window = try createBlurWindow(frame: screen.frame)
                
                let blurView = BlurView(
                    technique: technique ?? currentTechnique ?? "Custom",
                    screen: screen,
                    pomodoroCount: pomodoroCount,
                    isAnimatingOut: .init(
                        get: { self.isAnimatingOut },
                        set: { self.isAnimatingOut = $0 }
                    )
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
            
            if UserDefaults.standard.bool(forKey: "showNotifications") {
                try showBreakNotification()
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
        
        return window
    }
    
    private func playBreakSound() throws {
        if breakSound == nil {
            guard let sound = NSSound(named: "Glass") else {
                throw UnwindError.soundInitializationFailed
            }
            breakSound = sound
        }
        breakSound?.play()
    }
    
    private func showBreakNotification() throws {
        let content = UNMutableNotificationContent()
        content.title = "Time for a Break"
        content.body = "Take a minute to relax and rest your eyes"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.handleError(error)
            }
        }
    }
    
    private func getDismissalDuration(for technique: String) throws -> TimeInterval {
        switch technique {
        case "20-20-20 Rule":
            return 20
        case "Pomodoro Technique":
            // After 4 pomodoros, take a long break
            if pomodoroCount >= 4 {
                pomodoroCount = 0
                return longBreakDuration
            }
            return shortBreakDuration
        case "Custom":
            let duration = TimeInterval(UserDefaults.standard.integer(forKey: "breakDuration"))
            guard duration > 0 else { throw UnwindError.customRuleNotConfigured }
            return duration
        default:
            throw UnwindError.invalidTechnique
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
                
                // Reset and start the timer
                do {
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
                    self?.timeInterval = newValue  // Just update the time interval
                    self?.closeCustomRuleSettings()
                },
                onClose: { [weak self] in
                    self?.closeCustomRuleSettings()  // Just close
                }
            )
            .environment(\.colorScheme, .dark)
            
            let hostingView = NSHostingView(rootView: customRuleView)
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
    
    func startSelectedTechnique(technique: String) {
        do {
            guard !technique.isEmpty else {
                throw UnwindError.invalidTechnique
            }
            
            currentTechnique = technique
            
            switch technique {
            case "20-20-20 Rule":
                timeInterval = 1200  // 20 minutes
            case "Pomodoro Technique":
                timeInterval = 1500  // 25 minutes
                pomodoroCount += 1
            case "Custom":
                let reminderInterval = UserDefaults.standard.integer(forKey: "reminderInterval")
                let breakDuration = UserDefaults.standard.integer(forKey: "breakDuration")
                
                guard reminderInterval > 0 && breakDuration > 0 else {
                    throw UnwindError.customRuleNotConfigured
                }
                
                timeInterval = TimeInterval(reminderInterval)
                shortBreakDuration = TimeInterval(breakDuration)
            default:
                if let lastInterval = lastUsedInterval,
                   let lastBreakDuration = lastUsedBreakDuration {
                    timeInterval = lastInterval
                    shortBreakDuration = lastBreakDuration
                } else {
                    throw UnwindError.invalidTechnique
                }
            }
            
            // Set initial countdown value without starting timer
            nextBreakTime = Date().addingTimeInterval(timeInterval)
            let initialMinutes = Int(timeInterval) / 60
            let initialSeconds = Int(timeInterval) % 60
            timerState.timeString = String(format: "%d:%02d", initialMinutes, initialSeconds)
            
            // Only start timer if explicitly requested
            try startTimer()
            
        } catch {
            handleError(error)
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        
        // Store current settings before stopping
        if currentTechnique != nil {
            lastUsedInterval = timeInterval
            lastUsedBreakDuration = shortBreakDuration
        }
        
        // Don't reset currentTechnique, just the timer state
        nextBreakTime = nil
        breakSound?.stop()
        updateMenuBarTitle()
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
        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                .applicationIcon: NSImage(named: "UnwindLogo") ?? NSImage(),
                .applicationName: "Unwind",
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
    }
}

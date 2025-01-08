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
    private var shortBreakDuration: TimeInterval = 20 // For 20-20-20 rule
    private var longBreakDuration: TimeInterval = 300 // 5 minutes for Pomodoro
    private var pomodoroCount: Int = 0
    private var customBreakDuration: TimeInterval {
        TimeInterval(UserDefaults.standard.integer(forKey: "breakDuration"))
    }
    private var breakSound: NSSound?
    private var lastUsedInterval: TimeInterval?
    private var lastUsedBreakDuration: TimeInterval?
    private let timerState = TimerState()
    
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
        
        // Application Menu
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(NSMenuItem(title: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Show", action: #selector(showHomeScreen), keyEquivalent: "s"))
        appMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        
        // Fix the Hide Others menu item
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
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
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 100),  // Height will be adjusted automatically
            styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        homeWindow?.isMovableByWindowBackground = true
        homeWindow?.titlebarAppearsTransparent = true
        homeWindow?.titleVisibility = .hidden
        homeWindow?.backgroundColor = NSColor.clear
        homeWindow?.isOpaque = false
        homeWindow?.hasShadow = true
        
        // Create container view with size fitting
        let containerView = NSView(frame: .zero)  // Let the content determine the size
        containerView.autoresizingMask = [.width, .height]
        
        // Create and add visual effect view
        let visualEffect = NSVisualEffectView(frame: containerView.bounds)
        visualEffect.material = .windowBackground
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        visualEffect.alphaValue = 1
        visualEffect.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        containerView.addSubview(visualEffect)
        
        // Create and add SwiftUI hosting view
        let hostingView = NSHostingView(rootView: homeView)
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        if let layer = hostingView.layer {
            layer.backgroundColor = CGColor.clear
        }
        containerView.addSubview(hostingView)
        
        // Set the container as the window's content view
        homeWindow?.contentView = containerView
        
        // Size window to fit content
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
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Break Timer")
            button.title = " Ready"
            button.target = self
            button.action = #selector(showHomeScreen)  // Make the button directly show the main window
        }
        
        updateMenuBarTitle()
    }
    
    private func updateMenuBarTitle() {
        if let button = statusItem?.button {
            if timer != nil, let nextBreak = nextBreakTime {
                let timeRemaining = nextBreak.timeIntervalSinceNow
                if timeRemaining > 0 {
                    let minutes = Int(timeRemaining) / 60
                    let seconds = Int(timeRemaining) % 60
                    timerState.timeString = String(format: "%d:%02d", minutes, seconds)
                    button.title = " \(minutes)m"
                } else {
                    timerState.timeString = "0:00"
                    button.title = " 0m"
                }
            } else {
                timerState.timeString = ""
                button.title = " Ready"
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
                    self.updateTimeString(String(format: "%d:%02d", minutes, seconds))
                    
                    if let button = self.statusItem?.button {
                        button.title = " \(minutes)m"
                    }
                } else {
                    self.updateTimeString("0:00")
                    if let button = self.statusItem?.button {
                        button.title = " 0m"
                    }
                    
                    self.showBlurScreen(forTechnique: self.currentTechnique)
                    self.nextBreakTime = Date().addingTimeInterval(self.timeInterval)
                }
            }
        }
        
        // Set initial value
        let initialMinutes = Int(timeInterval) / 60
        let initialSeconds = Int(timeInterval) % 60
        updateTimeString(String(format: "%d:%02d", initialMinutes, initialSeconds))
        
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    @objc private func showHomeScreen() {
        NSApp.setActivationPolicy(.regular)
        
        if homeWindow == nil {
            createAndShowHomeWindow()
        }
        
        NSApp.activate(ignoringOtherApps: true)
        homeWindow?.makeKeyAndOrderFront(nil)
    }
    
    func showBlurScreen(forTechnique technique: String? = nil) {
        do {
            guard blurWindow == nil else { return }
            
            // Create a window for each screen
            for screen in NSScreen.screens {
                let window = try createBlurWindow(frame: screen.frame)
                
                let blurView = BlurView(technique: technique ?? currentTechnique ?? "Custom")
                window.contentView = NSHostingView(rootView: blurView)
                window.makeKeyAndOrderFront(nil)
                
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
            
            // Set up auto-dismissal with animation
            let dismissDuration = try getDismissalDuration(for: technique ?? currentTechnique ?? "Custom")
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration) { [weak self] in
                self?.skipBreak() // Use skipBreak instead of dismissBlurScreen for consistent animation
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
        case "20-20-20":
            return shortBreakDuration
        case "Pomodoro":
            return longBreakDuration
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
            
            // Trigger disappear animation in BlurView
            if let windows = NSApplication.shared.windows.filter({ $0 is KeyableWindow }).filter({ $0 != self.homeWindow }) as? [KeyableWindow] {
                for window in windows {
                    if let hostingView = window.contentView as? NSHostingView<BlurView> {
                        // Animate out
                        withAnimation(.easeOut(duration: 0.3)) {
                            hostingView.rootView.isAppearing = false
                        }
                    }
                }
                
                // Dismiss windows after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    for window in windows {
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
    }
    
    @objc func showSettings() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }  // Strong self since we need it for delegate
            
            if self.settingsWindow == nil || self.settingsWindow?.isVisible == false {
                self.settingsWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
                    styleMask: [.titled, .closable],
                    backing: .buffered,
                    defer: false
                )
                
                self.settingsWindow?.title = "App Settings"
                self.settingsWindow?.center()
                self.settingsWindow?.standardWindowButton(.miniaturizeButton)?.isEnabled = false
                self.settingsWindow?.standardWindowButton(.zoomButton)?.isEnabled = false
                
                let settingsView = AdvancedSettingsView()
                self.settingsWindow?.contentView = NSHostingView(rootView: settingsView)
                self.settingsWindow?.isReleasedWhenClosed = false
                self.settingsWindow?.delegate = self  // Now this will work
            }
            
            NSApp.activate(ignoringOtherApps: true)
            self.settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }
    
    func showCustomRuleSettings() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.customRuleWindow == nil || self.customRuleWindow?.isVisible == false {
                self.customRuleWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 300, height: 240),
                    styleMask: [.titled, .closable],
                    backing: .buffered,
                    defer: false
                )
                
                self.customRuleWindow?.title = "Custom Rule"
                self.customRuleWindow?.center()
                self.customRuleWindow?.titlebarAppearsTransparent = true
                self.customRuleWindow?.isMovableByWindowBackground = true
                self.customRuleWindow?.standardWindowButton(.miniaturizeButton)?.isHidden = true
                self.customRuleWindow?.standardWindowButton(.zoomButton)?.isHidden = true
                
                let customRuleView = CustomRuleView { [weak self] newValue in
                    self?.timeInterval = newValue
                    do {
                        try self?.startTimer()
                    } catch {
                        self?.handleError(error)
                    }
                }
                
                self.customRuleWindow?.contentView = NSHostingView(rootView: customRuleView)
                self.customRuleWindow?.isReleasedWhenClosed = false
                self.customRuleWindow?.delegate = self
            }
            
            NSApp.activate(ignoringOtherApps: true)
            self.customRuleWindow?.makeKeyAndOrderFront(nil)
        }
    }
    
    func startSelectedTechnique(technique: String) {
        do {
            guard !technique.isEmpty else {
                throw UnwindError.invalidTechnique
            }
            
            currentTechnique = technique
            pomodoroCount = 0
            
            switch technique {
            case "20-20-20":
                timeInterval = 1200  // 20 minutes
                shortBreakDuration = 20
            case "Pomodoro":
                timeInterval = 1500  // 25 minutes
                shortBreakDuration = 300
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
            
            // Set initial countdown value
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
            
            // Trigger disappear animation in BlurView
            if let windows = NSApplication.shared.windows.filter({ $0 is KeyableWindow }).filter({ $0 != self.homeWindow }) as? [KeyableWindow] {
                for window in windows {
                    if let hostingView = window.contentView as? NSHostingView<BlurView> {
                        // Animate out
                        withAnimation(.easeOut(duration: 0.3)) {
                            hostingView.rootView.isAppearing = false
                        }
                    }
                }
                
                // Dismiss windows after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    for window in windows {
                        window.orderOut(nil)
                    }
                    self.blurWindow = nil
                    self.breakSound?.stop()
                    
                    // Reset and start the timer
                    do {
                        self.nextBreakTime = Date().addingTimeInterval(self.timeInterval)
                        try self.startTimer()
                    } catch {
                        self.handleError(error)
                    }
                }
            }
        }
    }
}

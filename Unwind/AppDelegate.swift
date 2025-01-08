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
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        
        homeWindow?.isMovableByWindowBackground = true
        homeWindow?.titlebarAppearsTransparent = true
        homeWindow?.titleVisibility = .hidden
        homeWindow?.backgroundColor = .clear
        
        homeWindow?.center()
        homeWindow?.contentView = NSHostingView(rootView: homeView)
        homeWindow?.isReleasedWhenClosed = false
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
        }
        
        updateMenuBarTitle()
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Take Break Now", action: #selector(takeBreakNow), keyEquivalent: "b"))
        
        statusItem?.menu = menu
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
        if homeWindow == nil {
            homeWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            homeWindow?.title = "Unwind"
            homeWindow?.center()
            
            let homeView = HomeView(
                timeInterval: timeInterval,
                timerState: timerState,
                onTimeIntervalChange: { [weak self] newValue in
                    self?.timeInterval = newValue
                }
            )
            
            homeWindow?.contentView = NSHostingView(rootView: homeView)
            homeWindow?.isReleasedWhenClosed = false
        }
        
        homeWindow?.makeKeyAndOrderFront(nil)
    }
    
    func showBlurScreen(forTechnique technique: String? = nil) {
        do {
            guard blurWindow == nil else { return }
            
            guard let screen = NSScreen.main else {
                throw UnwindError.windowCreationFailed
            }
            
            let previewTechnique = technique ?? currentTechnique ?? "Custom"
            
            // Validate technique settings
            if previewTechnique == "Custom" {
                let breakDuration = UserDefaults.standard.integer(forKey: "breakDuration")
                let reminderInterval = UserDefaults.standard.integer(forKey: "reminderInterval")
                
                guard breakDuration > 0 && reminderInterval > 0 else {
                    throw UnwindError.customRuleNotConfigured
                }
            }
            
            // Create and configure blur window
            blurWindow = try createBlurWindow(frame: screen.frame)
            
            let blurView = BlurView(technique: previewTechnique)
            blurWindow?.contentView = NSHostingView(rootView: blurView)
            blurWindow?.makeKeyAndOrderFront(nil)
            
            // Handle sound
            if UserDefaults.standard.bool(forKey: "playSound") {
                try playBreakSound()
            }
            
            // Handle notification
            if UserDefaults.standard.bool(forKey: "showNotifications") {
                try showBreakNotification()
            }
            
            // Set up dismissal
            let dismissDuration = try getDismissalDuration(for: previewTechnique)
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration) { [weak self] in
                self?.dismissBlurScreen()
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
        
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        
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
            // Only close and nil the blur window
            self?.blurWindow?.orderOut(nil)  // Changed from close() to orderOut(nil)
            self?.blurWindow = nil
            self?.breakSound?.stop()
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
            guard let self = self else { return }  // Strong self since we need it for delegate
            
            if self.customRuleWindow == nil || self.customRuleWindow?.isVisible == false {
                self.customRuleWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                    styleMask: [.titled, .closable],
                    backing: .buffered,
                    defer: false
                )
                
                self.customRuleWindow?.title = "Custom Rule"
                self.customRuleWindow?.center()
                self.customRuleWindow?.standardWindowButton(.miniaturizeButton)?.isEnabled = false
                self.customRuleWindow?.standardWindowButton(.zoomButton)?.isEnabled = false
                
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
                self.customRuleWindow?.delegate = self  // Now this will work
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
}
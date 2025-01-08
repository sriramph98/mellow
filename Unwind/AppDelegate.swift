import Cocoa
import SwiftUI
import UserNotifications

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default interval if not set
        if UserDefaults.standard.double(forKey: "breakInterval") == 0 {
            UserDefaults.standard.set(1200, forKey: "breakInterval")
        }
        
        // Create the SwiftUI window first
        createAndShowHomeWindow()
        
        setupNotifications()
        setupMenuBar()
        startTimer()
        
        // Ensure app is active and window is front
        DispatchQueue.main.async { [weak self] in
            NSApplication.shared.activate(ignoringOtherApps: true)
            self?.homeWindow?.makeKeyAndOrderFront(nil)
        }
    }
    
    private func createAndShowHomeWindow() {
        let homeView = HomeView(timeInterval: timeInterval) { [weak self] newValue in
            self?.timeInterval = newValue
            self?.startTimer()
        }
        
        homeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Break Timer")
        }
        
        updateMenuBarTitle()
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show", action: #selector(showHomeScreen), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Skip Next Break", action: #selector(skipNextBreak), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Take Break Now", action: #selector(takeBreakNow), keyEquivalent: "b"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Unwind", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func updateMenuBarTitle() {
        if let nextBreak = nextBreakTime {
            let minutes = max(0, Int(nextBreak.timeIntervalSinceNow / 60))
            statusItem?.button?.title = " \(minutes)m"
        }
    }
    
    @objc private func skipNextBreak() {
        startTimer() // Resets the timer
    }
    
    @objc private func takeBreakNow() {
        showBlurScreen()
    }
    
    private func startTimer() {
        timer?.invalidate()
        // Set the next break time to timeInterval from now (not immediate)
        nextBreakTime = Date().addingTimeInterval(timeInterval)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateMenuBarTitle()
            
            if let nextBreak = self?.nextBreakTime,
               Date() >= nextBreak {
                self?.showBlurScreen()
                // Set next break time after current break
                self?.nextBreakTime = Date().addingTimeInterval(self?.timeInterval ?? 1200)
            }
        }
        
        // Update menu bar immediately to show initial countdown
        updateMenuBarTitle()
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
            
            let homeView = HomeView(timeInterval: timeInterval) { [weak self] newValue in
                self?.timeInterval = newValue
                self?.startTimer()
            }
            
            homeWindow?.contentView = NSHostingView(rootView: homeView)
            homeWindow?.isReleasedWhenClosed = false
        }
        
        homeWindow?.makeKeyAndOrderFront(nil)
    }
    
    func showBlurScreen() {
        if blurWindow != nil {
            return
        }
        
        let screen = NSScreen.main!
        blurWindow = KeyableWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        blurWindow?.level = .screenSaver
        blurWindow?.backgroundColor = .clear
        blurWindow?.isOpaque = false
        blurWindow?.hasShadow = false
        blurWindow?.acceptsMouseMovedEvents = true
        blurWindow?.ignoresMouseEvents = false
        
        let blurView = BlurView(technique: currentTechnique ?? "Custom")
        blurWindow?.contentView = NSHostingView(rootView: blurView)
        blurWindow?.makeKeyAndOrderFront(nil)
        
        // Play sound if enabled
        if UserDefaults.standard.bool(forKey: "playSound") {
            NSSound(named: "Glass")?.play()
        }
        
        // Show notification if enabled
        if UserDefaults.standard.bool(forKey: "showNotifications") {
            let content = UNMutableNotificationContent()
            content.title = "Time for a Break"
            content.body = "Take a minute to relax and rest your eyes"
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                                              content: content,
                                              trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
        
        // Update auto-dismiss duration based on technique
        let dismissDuration = switch currentTechnique {
        case "20-20-20": shortBreakDuration
        case "Pomodoro": longBreakDuration
        case "Custom": customBreakDuration
        default: longBreakDuration
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration) { [weak self] in
            self?.dismissBlurScreen()
            
            // For Pomodoro, track sessions
            if self?.currentTechnique == "Pomodoro" {
                self?.pomodoroCount += 1
                if self?.pomodoroCount == 4 {
                    self?.pomodoroCount = 0
                    self?.timeInterval = 1800 // 30-minute long break
                }
            }
        }
    }
    
    func dismissBlurScreen() {
        DispatchQueue.main.async { [weak self] in
            // Only close and nil the blur window
            self?.blurWindow?.orderOut(nil)  // Changed from close() to orderOut(nil)
            self?.blurWindow = nil
        }
    }
    
    @objc func showSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 150), // Smaller height
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow?.title = "App Settings"
            settingsWindow?.center()
            settingsWindow?.standardWindowButton(.miniaturizeButton)?.isEnabled = false
            settingsWindow?.standardWindowButton(.zoomButton)?.isEnabled = false
            
            let settingsView = AdvancedSettingsView()
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.isReleasedWhenClosed = true
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    func showCustomRuleSettings() {
        if customRuleWindow == nil {
            customRuleWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            customRuleWindow?.title = "Custom Rule"
            customRuleWindow?.center()
            customRuleWindow?.standardWindowButton(.miniaturizeButton)?.isEnabled = false
            customRuleWindow?.standardWindowButton(.zoomButton)?.isEnabled = false
            
            let customRuleView = CustomRuleView { [weak self] newValue in
                self?.timeInterval = newValue
                self?.startTimer()
            }
            
            customRuleWindow?.contentView = NSHostingView(rootView: customRuleView)
            customRuleWindow?.isReleasedWhenClosed = true
        }
        
        NSApp.activate(ignoringOtherApps: true)
        customRuleWindow?.makeKeyAndOrderFront(nil)
    }
    
    func startSelectedTechnique(technique: String) {
        currentTechnique = technique
        pomodoroCount = 0
        
        switch technique {
        case "20-20-20":
            timeInterval = 1200 // 20 minutes
            shortBreakDuration = 20 // 20 seconds
        case "Pomodoro":
            timeInterval = 1500 // 25 minutes
            shortBreakDuration = 300 // 5 minutes
        case "Custom":
            timeInterval = TimeInterval(UserDefaults.standard.integer(forKey: "reminderInterval"))
            shortBreakDuration = customBreakDuration
        default:
            break
        }
        
        startTimer()
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        currentTechnique = nil
        updateMenuBarTitle()
    }
    
    // Add this method to handle window closing
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
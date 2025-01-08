import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var blurWindow: NSWindow?
    var homeWindow: NSWindow?
    var timer: Timer?
    @objc dynamic var timeInterval: TimeInterval = UserDefaults.standard.double(forKey: "breakInterval") {
        didSet {
            UserDefaults.standard.set(timeInterval, forKey: "breakInterval")
            updateMenuBarTitle()
        }
    }
    private var nextBreakTime: Date?
    
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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        homeWindow?.title = "Unwind"
        homeWindow?.center()
        homeWindow?.contentView = NSHostingView(rootView: homeView)
        homeWindow?.isReleasedWhenClosed = false
        homeWindow?.makeKeyAndOrderFront(nil)
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
        menu.addItem(NSMenuItem(title: "Show", action: #selector(showHomeScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Skip Next Break", action: #selector(skipNextBreak), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Take Break Now", action: #selector(takeBreakNow), keyEquivalent: "b"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
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
        // If there's already a blur window, don't create another one
        if blurWindow != nil {
            return
        }
        
        let screen = NSScreen.main!
        blurWindow = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        blurWindow?.level = .screenSaver
        blurWindow?.backgroundColor = .clear
        blurWindow?.isOpaque = false
        blurWindow?.hasShadow = false
        
        let blurView = BlurView()
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
        
        // Auto-dismiss after 1 minute
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.dismissBlurScreen()
        }
    }
    
    func dismissBlurScreen() {
        DispatchQueue.main.async { [weak self] in
            self?.blurWindow?.close()
            self?.blurWindow = nil
        }
    }
}
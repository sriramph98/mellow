import Cocoa
import SwiftUI
import ApplicationServices

enum MellowError: Error {
    case invalidTechnique
    case customRuleNotConfigured
    case timerInitializationFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidTechnique:
            return "Invalid or empty technique selected"
        case .customRuleNotConfigured:
            return "Custom rule interval not configured"
        case .timerInitializationFailed:
            return "Failed to initialize timer"
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

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var blurWindow: NSWindow?
    var homeWindow: NSWindow?
    var timer: Timer?
    var settingsWindow: NSWindow?
    var customRuleWindow: NSWindow?
    var settingsPopover: NSPopover?
    var settingsViewController: NSViewController?
    @objc dynamic var timeInterval: TimeInterval = UserDefaults.standard.double(forKey: "breakInterval") {
        didSet {
            UserDefaults.standard.set(timeInterval, forKey: "breakInterval")
            updateMenuBarTitle()
        }
    }
    var nextBreakTime: Date?
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
    @AppStorage("customInterval") var customInterval: TimeInterval = 1200 // Default 20 minutes
    @AppStorage("isCustomRuleConfigured") var isCustomRuleConfigured: Bool = false
    private var pausedTimeRemaining: TimeInterval?
    var overlayDismissed = false
    @Published var homeWindowInteractionDisabled = false
    private var assertionID: IOPMAssertionID = 0
    private var hasValidPowerAssertion: Bool = false
    
    // Helper function to configure window dragging behavior
    private func configureWindowDragging(for window: NSWindow, allowDragging: Bool = false) {
        // Allow dragging by title bar but prevent dragging by content area
        window.isMovable = true
        window.isMovableByWindowBackground = allowDragging
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // Check accessibility permission
        checkAccessibilityPermission()
        
        setupMinimalMainMenu()
        
        if UserDefaults.standard.double(forKey: "breakInterval") == 0 {
            UserDefaults.standard.set(1200, forKey: "breakInterval")
        }
        
        createAndShowHomeWindow()
        setupMenuBar()
        
        // Only show the home window if overlay hasn't been dismissed
        if !overlayDismissed {
            DispatchQueue.main.async { [weak self] in
                NSApplication.shared.activate(ignoringOtherApps: true)
                self?.homeWindow?.makeKeyAndOrderFront(nil)
            }
        }
        
        // Add observer for screen lock/unlock notifications
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        // Add observers for screen saver
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLock),
            name: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil
        )
    }
    
    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessibilityEnabled {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "Mellow needs accessibility permission to show break reminders above other windows. Please grant permission in System Settings > Privacy & Security > Accessibility."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
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
            timeInterval: .init(
                get: { self.timeInterval },
                set: { self.timeInterval = $0 }
            ),
            timerState: timerState,
            onTimeIntervalChange: { [weak self] newValue in
                self?.timeInterval = newValue
            }
        )
        
        homeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 100),
            styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure window dragging behavior
        configureWindowDragging(for: homeWindow!)
        
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
        homeWindow?.isMovableByWindowBackground = false
        homeWindow?.titlebarAppearsTransparent = true
        homeWindow?.titleVisibility = .hidden
        homeWindow?.backgroundColor = .clear
        homeWindow?.isOpaque = false
        homeWindow?.hasShadow = true
        homeWindow?.title = "Mellow"  // Keep title for Mission Control
        
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
                            button.title = String(format: " ⏸ %@", timerState.timeString)
                        } else {
                            timerState.timeString = String(format: "%d:%02d", minutes, seconds)
                            button.title = String(format: " ⏸ %@", timerState.timeString)
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
                            button.title = String(format: " %@", timerState.timeString)
                        } else {
                            timerState.timeString = String(format: "%d:%02d", minutes, seconds)
                            button.title = String(format: " %@", timerState.timeString)
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
        overlayDismissed = true
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
        
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
            updateTimer()
            updateMenuBarTitle()
        } else {
            throw MellowError.timerInitializationFailed
        }
    }
    
    @objc private func showHomeScreen() {
        // Only proceed if overlay hasn't been dismissed
        if overlayDismissed {
            return
        }
        
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
    
    private func preventDisplaySleep() {
        // Only attempt if we don't already have a valid assertion
        guard !hasValidPowerAssertion else { return }
        
        var localAssertionID: IOPMAssertionID = 0
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,  // Changed assertion type
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Mellow break time" as CFString,
            &localAssertionID
        )
        
        if success == kIOReturnSuccess {
            assertionID = localAssertionID
            hasValidPowerAssertion = true
        } else {
            print("Failed to create power assertion with error: \(success)")
            // Reset state
            assertionID = 0
            hasValidPowerAssertion = false
        }
    }
    
    private func allowDisplaySleep() {
        if hasValidPowerAssertion && assertionID != 0 {
            let success = IOPMAssertionRelease(assertionID)
            if success == kIOReturnSuccess {
                assertionID = 0
                hasValidPowerAssertion = false
            } else {
                print("Failed to release power assertion with error: \(success)")
            }
        }
    }
    
    func showBlurScreen(forTechnique technique: String? = nil) {
        do {
            // Check if overlay is enabled
            guard UserDefaults.standard.bool(forKey: "showOverlay") else { return }
            
            // No longer need to guard blurWindow since we clean up beforehand
            isAnimatingOut = false
            
            // Prevent display sleep before showing windows
            preventDisplaySleep()
            
            // Create blur windows for each screen
            for screen in NSScreen.screens {
                let window = try createBlurWindow(frame: screen.frame)
                
                // Check if this is the internal display
                let isInternalDisplay = isInternalDisplay(screen)
                
                let blurView = BlurView(
                    technique: technique ?? currentTechnique ?? "Custom",
                    screen: screen,
                    pomodoroCount: pomodoroCount,
                    isAnimatingOut: .init(
                        get: { self.isAnimatingOut },
                        set: { [weak self] newValue in 
                            self?.isAnimatingOut = newValue
                            if newValue {
                                // Clear the window references after animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                    self?.blurWindows.forEach { $0.orderOut(nil) }
                                    self?.blurWindows.removeAll()
                                    
                                    // Release screen sleep prevention
                                    self?.allowDisplaySleep()
                                    
                                    // Restart timer after break
                                    self?.nextBreakTime = Date().addingTimeInterval(self?.timeInterval ?? 1200)
                                    self?.timer = Timer(fire: Date(), interval: 0.5, repeats: true) { [weak self] _ in
                                        self?.updateTimer()
                                    }
                                    if let timer = self?.timer {
                                        RunLoop.main.add(timer, forMode: .common)
                                    }
                                }
                            }
                        }
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
            cleanupBlurWindows()
            allowDisplaySleep()
            handleError(error)
        }
    }
    
    // Helper function to determine if a screen is internal
    private func isInternalDisplay(_ screen: NSScreen) -> Bool {
        // Method 1: Check using CGMainDisplayID
        let mainDisplayCheck = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber") as NSDeviceDescriptionKey] as? CGDirectDisplayID == CGMainDisplayID()
        
        // Method 2: Check if it's the first screen
        let isFirstScreen = NSScreen.screens.first == screen
        
        // Method 3: Check if it's the main screen
        let isMainScreen = screen == NSScreen.main
        
        // Return true if any of the checks pass
        return mainDisplayCheck || isFirstScreen || isMainScreen
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
        
        // Create a visual effect view for the window background
        let visualEffect = NSVisualEffectView(frame: window.contentView?.bounds ?? .zero)
        visualEffect.material = .fullScreenUI
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        
        // Force dark appearance for consistent look
        if let darkAppearance = NSAppearance(named: .darkAqua) {
            visualEffect.appearance = darkAppearance
        }
        
        // Add semi-transparent black background
        if let layer = visualEffect.layer {
            layer.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        }
        
        // Make visual effect view resize with window
        visualEffect.autoresizingMask = [.width, .height]
        
        // Set as window background
        window.contentView = visualEffect
        
        // Disable window dragging
        configureWindowDragging(for: window, allowDragging: false)
        
        return window
    }
    
    private func playBreakSound() throws {
        if breakSound == nil {
            guard let sound = NSSound(named: "Glass") else {
                throw MellowError.timerInitializationFailed
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
                
                // Release screen sleep prevention
                self.allowDisplaySleep()
                
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
        // Close any existing popover first
        settingsPopover?.close()
        
        // Create the settings view
        let settingsView = SettingsView(onClose: { [weak self] in
            self?.settingsPopover?.close()
        })
        
        // Create hosting view controller for the SwiftUI view
        let hostingController = NSHostingController(rootView: settingsView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Create and configure the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 360)
        popover.behavior = .transient // Closes when clicking outside
        popover.contentViewController = hostingController
        popover.animates = true
        self.settingsPopover = popover
        self.settingsViewController = hostingController
        
        // Determine the source to show the popover from
        if let statusButton = statusItem?.button {
            // Show from menu bar status item
            popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
        } else if let homeWindow = homeWindow, homeWindow.isVisible {
            // Show from settings button in home window
            popover.showFromTaggedView(tag: 1001, in: homeWindow, preferredEdge: .maxY)
        } else {
            // If no good anchor point, create and show the home window first
            if homeWindow == nil {
                createAndShowHomeWindow()
            } else {
                showHomeScreen()
            }
            
            // Delay showing the popover until the window is visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, let homeWindow = self.homeWindow else { return }
                popover.showFromTaggedView(tag: 1001, in: homeWindow, preferredEdge: .maxY)
            }
        }
    }
    
    func showCustomRuleSettings() {
        // Close any existing popover first
        settingsPopover?.close()
        
        let customRuleView = CustomRuleView(
            onSave: { [weak self] interval in
                guard let self = self else { return }
                // Update the custom interval
                self.customInterval = interval
                
                // If Custom is the selected technique, update the current timeInterval
                if self.currentTechnique == "Custom" {
                    self.timeInterval = interval
                }
                
                // Mark as configured and close the popover
                self.isCustomRuleConfigured = true
                self.settingsPopover?.close()
            },
            onClose: { [weak self] in
                self?.settingsPopover?.close()
            }
        )
        
        // Create hosting controller for SwiftUI view
        let hostingController = NSHostingController(rootView: customRuleView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Create and configure the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 440, height: 420)  // Updated dimensions to match vertical layout
        popover.behavior = .transient // Closes when clicking outside
        popover.contentViewController = hostingController
        popover.animates = true
        self.settingsPopover = popover
        self.settingsViewController = hostingController
        
        // Determine where to show the popover
        if let homeWindow = homeWindow, homeWindow.isVisible {
            if let customButton = homeWindow.contentView?.findViewWithTag(1002) {
                // Show from custom rule button if available
                popover.show(relativeTo: customButton.bounds, of: customButton, preferredEdge: .maxY)
            } else {
                // Show from center of window
                let centerRect = NSRect(x: homeWindow.frame.width/2, y: homeWindow.frame.height/2, width: 0, height: 0)
                popover.show(relativeTo: centerRect, of: homeWindow.contentView!, preferredEdge: .maxY)
            }
        } else {
            // If home window isn't visible, show it first
            if homeWindow == nil {
                createAndShowHomeWindow()
            } else {
                showHomeScreen()
            }
            
            // Delay showing the popover until the window is visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, let homeWindow = self.homeWindow else { return }
                let centerRect = NSRect(x: homeWindow.frame.width/2, y: homeWindow.frame.height/2, width: 0, height: 0)
                popover.show(relativeTo: centerRect, of: homeWindow.contentView!, preferredEdge: .maxY)
            }
        }
    }
    
    func startSelectedTechnique(technique: String, isReset: Bool = false) {
        do {
            guard !technique.isEmpty else {
                throw MellowError.invalidTechnique
            }
            
            // Reset state first
            timer?.invalidate()
            timer = nil
            timerState.isPaused = false
            pausedTimeRemaining = nil
            
            // Set the current technique first
            currentTechnique = technique
            
            // Initialize timeInterval based on technique
            switch technique {
            case "20-20-20 Rule":
                timeInterval = 1200  // 20 minutes
            case "Pomodoro Technique":
                timeInterval = 1500  // 25 minutes
                if pomodoroCount == 0 {
                    pomodoroCount = 1
                    print("🍅 Starting Pomodoro - Count: 1/4")
                } else if isReset {
                    print("🍅 Timer reset - Continuing at Count: \(pomodoroCount)/4")
                }
            case "Custom":
                // Ensure we have a valid custom interval
                guard customInterval > 0 else {
                    throw MellowError.customRuleNotConfigured
                }
                timeInterval = customInterval
            default:
                throw MellowError.invalidTechnique
            }
            
            // Set next break time
            nextBreakTime = Date().addingTimeInterval(timeInterval)
            
            // Create and start timer
            let newTimer = Timer(fire: Date(), interval: 0.5, repeats: true) { [weak self] _ in
                self?.updateTimer()
            }
            
            // Add timer to run loop
            RunLoop.main.add(newTimer, forMode: .common)
            timer = newTimer
            
            // Update display
            updateTimer()
            updateMenuBarTitle()
            
        } catch {
            // Reset state on error
            timer?.invalidate()
            timer = nil
            timerState.isPaused = false
            pausedTimeRemaining = nil
            nextBreakTime = nil
            currentTechnique = nil
            
            handleError(error)
        }
    }
    
    func stopTimer() {
        // Dismiss any existing overlay first
        if let window = blurWindow {
            window.orderOut(nil)
            blurWindow = nil
            blurWindows.forEach { $0.orderOut(nil) }
            blurWindows.removeAll()
        }
        
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
        
        // Ensure screen saver is allowed when timer is stopped
        if let blurWindow = blurWindow {
            if let hostingView = blurWindow.contentView as? NSHostingView<BlurView> {
                hostingView.rootView.screenSaverManager.allowScreenSaver()
            }
        }
        
        // Release screen sleep prevention
        allowDisplaySleep()
        
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
                
                // Release screen sleep prevention
                self.allowDisplaySleep()
                
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
                if let timer = timer {
                    RunLoop.main.add(timer, forMode: .common)
                }
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
    
    func updateTimer() {
        guard let nextBreak = nextBreakTime, timer != nil else { return }
        
        let timeRemaining = nextBreak.timeIntervalSinceNow
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if timeRemaining > 0 {
                let minutes = Int(timeRemaining) / 60
                let seconds = Int(timeRemaining) % 60
                
                // Only show overlay when timer is running and not paused
                if timeRemaining <= 10 && self.blurWindow == nil && !self.timerState.isPaused && self.timer != nil {
                    self.showTestBlurScreen(timeRemaining: timeRemaining)
                }
                
                // Update timer state and menu bar
                let newTimeString: String
                if minutes == 0 {
                    newTimeString = String(format: "%ds", seconds)
                } else {
                    newTimeString = String(format: "%d:%02d", minutes, seconds)
                }
                
                self.timerState.timeString = newTimeString
                if let button = self.statusItem?.button {
                    button.title = " \(newTimeString)"
                }
            } else {
                // Check if timer has reached zero
                if timeRemaining <= 0 {
                    // Ensure timer is valid and not paused
                    guard self.timer?.isValid == true && !self.timerState.isPaused else { return }
                    
                    // Store current technique and clean up timer state atomically
                    let currentTech = self.currentTechnique
                    self.cleanupTimerState()
                    
                    // Show blur screen with proper state management
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        // Force cleanup any existing blur windows
                        self.cleanupBlurWindows()
                        // Show new blur screen
                        self.showBlurScreen(forTechnique: currentTech)
                    }
                }
            }
        }
    }
    
    // New helper method for timer cleanup
    private func cleanupTimerState() {
        self.timer?.invalidate()
        self.timer = nil
        self.nextBreakTime = nil
        self.isAnimatingOut = false
    }
    
    // New helper method for blur window cleanup
    private func cleanupBlurWindows() {
        self.blurWindows.forEach { $0.orderOut(nil) }
        self.blurWindows.removeAll()
        self.blurWindow?.orderOut(nil)
        self.blurWindow = nil
    }
    
    func showTestBlurScreen(timeRemaining: TimeInterval = 10) {
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
            overlayDismissed = false
            
            // Prevent display sleep
            preventDisplaySleep()
            
            // Try to find the internal display
            var targetScreen: NSScreen? = nil
            
            // First try to find the internal display
            for screen in NSScreen.screens {
                if isInternalDisplay(screen) {
                    targetScreen = screen
                    break
                }
            }
            
            // If no internal display found, fall back to main screen
            if targetScreen == nil {
                targetScreen = NSScreen.main ?? NSScreen.screens.first
            }
            
            // Create window if we have a valid screen
            if let screen = targetScreen {
                // Get menu bar height and add padding
                let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 24
                let topPadding: CGFloat = 16 // Space below menu bar
                
                // Create window with dynamic size
                let window = try createBlurWindow(frame: .zero)
                
                // Configure window
                window.level = .floating
                window.isMovable = false
                window.hasShadow = true
                window.backgroundColor = .clear
                window.title = "Mellow"  // Add title for Mission Control
                
                let overlayView = OverlayView(
                    isAnimatingOut: .init(
                        get: { self.isAnimatingOut },
                        set: { [weak self] newValue in 
                            self?.isAnimatingOut = newValue
                            if newValue {
                                // Clear the window references after animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                    self?.blurWindows.forEach { $0.orderOut(nil) }
                                    self?.blurWindows.removeAll()
                                    
                                    // Release screen sleep prevention
                                    self?.allowDisplaySleep()
                                    
                                    // Restart timer after break
                                    self?.nextBreakTime = Date().addingTimeInterval(self?.timeInterval ?? 1200)
                                    self?.timer = Timer(fire: Date(), interval: 0.5, repeats: true) { [weak self] _ in
                                        self?.updateTimer()
                                    }
                                    if let timer = self?.timer {
                                        RunLoop.main.add(timer, forMode: .common)
                                    }
                                }
                            }
                        }
                    ),
                    initialTimeRemaining: timeRemaining,
                    onComplete: { [weak self] in
                        // Take a break immediately
                        DispatchQueue.main.async { [weak self] in
                            if let self = self {
                                // Reset the timer first to prevent any race conditions
                                self.timer?.invalidate()
                                self.timer = nil
                                self.nextBreakTime = nil
                                
                                // Show blur screen with a slight delay to ensure clean transition
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    self.showBlurScreen(forTechnique: self.currentTechnique)
                                }
                            }
                        }
                    }
                )
                    .frame(width: 420)  // Fixed width for overlay
                
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
            // Release screen sleep prevention on error
            allowDisplaySleep()
            handleError(error)
        }
    }
    
    @objc private func handleScreenLock() {
        // Save current timer state and pause if running
        if let nextBreak = nextBreakTime {
            pausedTimeRemaining = nextBreak.timeIntervalSinceNow
            timer?.invalidate()
            timer = nil
            timerState.isPaused = true
            updateMenuBarTitle()
        }
    }
    
    @objc private func handleScreenUnlock() {
        // Resume timer if it was paused
        if let remaining = pausedTimeRemaining {
            nextBreakTime = Date().addingTimeInterval(remaining)
            pausedTimeRemaining = nil
            
            timer = Timer(fire: Date(), interval: 0.5, repeats: true) { [weak self] _ in
                self?.updateTimer()
            }
            if let timer = timer {
                RunLoop.main.add(timer, forMode: .common)
            }
            timerState.isPaused = false
            updateMenuBarTitle()
        }
    }
    
    func showBlurWindow() {
        if blurWindow == nil {
            blurWindow = NSWindow(
                contentRect: NSScreen.main?.frame ?? .zero,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            blurWindow?.level = .floating
            blurWindow?.backgroundColor = .clear
            blurWindow?.isOpaque = false
            blurWindow?.hasShadow = false
            
            // Disable window dragging
            if let window = blurWindow {
                configureWindowDragging(for: window, allowDragging: false)
            }
            
            // Create BlurView with required parameters
            let blurView = BlurView(
                technique: currentTechnique ?? "Custom",
                screen: NSScreen.main ?? NSScreen.screens[0],
                pomodoroCount: pomodoroCount,
                isAnimatingOut: .init(
                    get: { self.isAnimatingOut },
                    set: { [weak self] newValue in 
                        self?.isAnimatingOut = newValue
                    }
                ),
                showContent: true
            )
            blurWindow?.contentView = NSHostingView(rootView: blurView)
        }
        
        blurWindow?.makeKeyAndOrderFront(nil)
        
        // Prevent screen sleep using IOKit
        preventDisplaySleep()
    }
    
    func hideBlurWindow() {
        blurWindow?.orderOut(nil)
        allowDisplaySleep()
    }
}

// MARK: - Utility Extensions

// Helper extension to find views by tag
extension NSView {
    func findViewWithTag(_ tag: Int) -> NSView? {
        if self.tag == tag {
            return self
        }
        
        for subview in subviews {
            if let view = subview.findViewWithTag(tag) {
                return view
            }
        }
        
        return nil
    }
}

// MARK: - NSPopover Extensions
extension NSPopover {
    // Convenience method to show popover from a tagged view in a window
    func showFromTaggedView(tag: Int, in window: NSWindow, preferredEdge: NSRectEdge = .maxY) {
        if let button = window.contentView?.findViewWithTag(tag) {
            self.show(relativeTo: button.bounds, of: button, preferredEdge: preferredEdge)
        }
    }
}

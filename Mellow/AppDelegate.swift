import Cocoa
import SwiftUI
import ApplicationServices
import IOKit.pwr_mgt

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

class TimerState: ObservableObject {
    @Published var timeString: String = ""
    @Published var isPaused: Bool = false
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var homeWindow: HomeWindowController?
    var settingsWindow: NSWindow?
    var customRuleWindow: NSWindow?
    var timer: Timer?
    var settingsPopover: NSPopover?
    var settingsViewController: NSViewController?
    @objc dynamic var timeInterval: TimeInterval = 1200 // Default to 20 minutes
    var nextBreakTime: Date?
    private var currentTechnique: String?
    private var shortBreakDuration: TimeInterval = 20 // Default 20 seconds
    private var longBreakDuration: TimeInterval = 300 // Default 5 minutes
    private var pomodoroCount: Int = 0
    private var customBreakDuration: TimeInterval {
        TimeInterval(UserDefaults.standard.integer(forKey: "breakDuration"))
    }
    private var breakSound: NSSound?
    private var lastUsedInterval: TimeInterval?
    private var lastUsedBreakDuration: TimeInterval?
    private let timerState = TimerState()
    @Published private var isAnimatingOut = false
    @AppStorage("customInterval") var customInterval: TimeInterval = 1200 // Default 20 minutes
    @AppStorage("isCustomRuleConfigured") var isCustomRuleConfigured: Bool = false
    var pausedTimeRemaining: TimeInterval?
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
        
        // Add observer for break skip notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBreakSkip),
            name: NSNotification.Name("MellowBreakSkip"),
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
        
        homeWindow = HomeWindowController(rootView: homeView)
        homeWindow?.window?.title = "Mellow"  // Keep title for Mission Control
        
        // Configure window for appearance modes
        homeWindow?.window?.appearance = NSAppearance(named: .darkAqua)
        homeWindow?.window?.isMovableByWindowBackground = false
        homeWindow?.window?.titlebarAppearsTransparent = true
        homeWindow?.window?.titleVisibility = .hidden
        homeWindow?.window?.backgroundColor = .clear
        homeWindow?.window?.isOpaque = false
        homeWindow?.window?.hasShadow = true
        
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
        
        homeWindow?.window?.contentView = containerView
        homeWindow?.window?.setContentSize(hostingView.fittingSize)
        homeWindow?.window?.center()
        homeWindow?.window?.isReleasedWhenClosed = false
        homeWindow?.window?.delegate = self
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
        if homeWindow?.window?.isVisible != true {
            NSApp.setActivationPolicy(.regular)
        }
        
        if homeWindow == nil {
            createAndShowHomeWindow()
        }
        
        // Ensure window is visible and app is active
        if let window = homeWindow?.window {
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Play the break sound
            try? self.playBreakSound()
            
            // Prevent screen sleep during break
            self.preventDisplaySleep()
            
            // Determine break duration based on technique
            let techniqueName = technique ?? self.currentTechnique ?? "20-20-20 Rule"
            let breakDuration: TimeInterval
            
            do {
                breakDuration = try self.getDismissalDuration(for: techniqueName)
            } catch {
                self.handleError(error)
                return
            }
            
            // Create and show full-screen overlay windows on all screens
            self.showFullscreenOverlays(technique: techniqueName, duration: breakDuration)
            
            // After the break duration, handle break completion
            DispatchQueue.main.asyncAfter(deadline: .now() + breakDuration) { [weak self] in
                self?.handleBreakComplete()
            }
        }
    }
    
    private var overlayWindows: [NSWindow] = []
    
    private func showFullscreenOverlays(technique: String, duration: TimeInterval) {
        // Close any existing overlay windows
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        
        // Create event monitor to block all interactions outside the overlay windows
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            // Prevent any interactions with other applications during break
            guard let self = self, !self.overlayWindows.isEmpty else { return }
            
            // If we're in a break, suppress the event
            NSApp.sendEvent(NSEvent.mouseEvent(
                with: .mouseMoved,
                location: NSPoint(x: 0, y: 0),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            )!)
        }
        
        // Create an overlay window for each screen
        for screen in NSScreen.screens {
            // Create a window that covers the entire screen including the menu bar
            let overlayWindow = BreakOverlayWindow(
                contentRect: screen.frame,
                screen: screen,
                technique: technique,
                endTime: Date().addingTimeInterval(duration),
                onSkip: { [weak self] in
                    self?.skipBreak()
                }
            )
            
            // Store the window reference
            overlayWindows.append(overlayWindow)
            
            // Show the window
            overlayWindow.makeKeyAndOrderFront(nil)
            overlayWindow.orderFrontRegardless()
        }
        
        // Ensure all windows are the top-most windows by using a timer
        let refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, !self.overlayWindows.isEmpty else {
                timer.invalidate()
                return
            }
            
            // Bring all overlay windows to front
            for window in self.overlayWindows {
                window.orderFrontRegardless()
            }
        }
        
        // Keep the timer alive by adding it to the appropriate run loops
        RunLoop.main.add(refreshTimer, forMode: .common)
        
        // We don't need to store break information in UserDefaults anymore since
        // we're not showing it in the app window, but using fullscreen overlays
        
        // Post notification to update any interested components
        NotificationCenter.default.post(
            name: NSNotification.Name("MellowBreakStarted"),
            object: nil
        )
    }
    
    private func handleBreakComplete() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Close all overlay windows
            for window in self.overlayWindows {
                window.orderOut(nil)
            }
            self.overlayWindows.removeAll()
            
            // Stop the break sound
            self.breakSound?.stop()
            
            // Allow screen sleep
            self.allowDisplaySleep()
            
            // Post notification that break ended
            NotificationCenter.default.post(
                name: NSNotification.Name("MellowBreakEnded"),
                object: nil
            )
            
            // Start the next timer
            do {
                self.nextBreakTime = Date().addingTimeInterval(self.timeInterval)
                try self.startTimer()
            } catch {
                self.handleError(error)
            }
        }
    }
    
    private func createBlurWindow(frame: NSRect) throws -> NSWindow {
        // This method is no longer needed, but keeping a simple implementation
        // to prevent potential crashes
        return NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
    }
    
    private func playBreakSound() throws {
        // Check if sound is enabled in settings
        let playSound = UserDefaults.standard.bool(forKey: "playSound")
        guard playSound else { return }
        
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
            return 20  // 20 seconds break
        case "Pomodoro Technique":
            if pomodoroCount == 4 {
                return 1800  // 30 minutes for long break after 4 work sessions
            }
            return 300  // 5 minutes for short breaks
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
    
    func dismissAllWindows() {
        // Get all notification windows
        let notificationWindows = NSApplication.shared.windows
            .filter { $0 != self.homeWindow?.window }
            
        // Close any notification windows
        for window in notificationWindows {
            if window.title == "Mellow" && window.level == .floating {
                window.orderOut(nil)
            }
        }
        
        // Close any settings windows
        if let settingsWindow = settingsWindow {
            settingsWindow.orderOut(nil)
        }
        
        // Dismiss any popovers
        if settingsPopover?.isShown == true {
            settingsPopover?.close()
        }
        
                self.breakSound?.stop()
                
                // Release screen sleep prevention
        allowDisplaySleep()
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
        } else if let homeWindow = homeWindow?.window, homeWindow.isVisible {
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
                guard let self = self, let homeWindow = self.homeWindow?.window else { return }
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
        if let homeWindow = homeWindow?.window, homeWindow.isVisible {
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
                guard let self = self, let homeWindow = self.homeWindow?.window else { return }
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
                    // When resetting, increment the count but cap at 4
                    pomodoroCount = min(pomodoroCount + 1, 4)
                    print("🍅 Timer reset - Count: \(pomodoroCount)/4")
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
        if sender == homeWindow?.window {
            homeWindow?.window?.orderOut(nil)
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
            
            // Close all overlay windows
            for window in self.overlayWindows {
                window.orderOut(nil)
            }
            self.overlayWindows.removeAll()
                
            self.breakSound?.stop()
                
            // Release screen sleep prevention
            self.allowDisplaySleep()
                
            // Reset timer state
            self.timer?.invalidate()
            self.timer = nil
            self.timerState.isPaused = false
            self.pausedTimeRemaining = nil
            
            // Start a new timer with the current technique
            if let technique = self.currentTechnique {
                // For Pomodoro, handle count based on break type
                if technique == "Pomodoro Technique" {
                    if self.pomodoroCount == 4 {
                        // After long break, reset to 1
                        self.pomodoroCount = 1
                        print("🍅 Long break skipped - Starting new cycle at Count: 1/4")
                    } else {
                        // After short break, increment count but cap at 4
                        self.pomodoroCount = min(self.pomodoroCount + 1, 4)
                        print("🍅 Break skipped - Count: \(self.pomodoroCount)/4")
                    }
                }
                // Pass false to isReset to prevent double incrementing
                self.startSelectedTechnique(technique: technique, isReset: false)
            }
            
            // Update menu bar title
            self.updateMenuBarTitle()
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
                if self?.homeWindow?.window?.isVisible != true {
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
                // Timer has ended, show break screen
                self.timer?.invalidate()
                self.timer = nil
                self.showBlurScreen(forTechnique: self.currentTechnique)
            }
        }
    }
    
    // New helper method for timer cleanup
    private func cleanupTimerState() {
        self.timer?.invalidate()
        self.timer = nil
        self.nextBreakTime = nil
    }
    
    // New helper method for blur window cleanup
    private func cleanupBlurWindows() {
        // Empty method as we've removed blur windows
    }
    
    func showTestBlurScreen(timeRemaining: TimeInterval = 10) {
        // This method is now empty as we've removed the blur screen functionality
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
    
    func showOverlayWindow(on screen: NSScreen) {
        // This method is no longer needed as we're removing the overlay feature
        // Keeping the method but making it empty to avoid breaking any callers
    }
    
    func showBlurWindow() {
        // This method is no longer needed as we're removing the blur window feature
        // Keeping the method but making it empty to avoid breaking any callers
    }
    
    func hideBlurWindow() {
        // This method is no longer needed as we're removing the blur window feature
        // Keeping the method but making it empty to avoid breaking any callers
    }
    
    func dismissMellowNotification() {
        // Get all notification windows
        let notificationWindows = NSApplication.shared.windows
            .filter { $0 != self.homeWindow?.window }
            
        // Close any notification windows
        for window in notificationWindows {
            if window.title == "Mellow" && window.level == .floating {
                window.orderOut(nil)
            }
        }
    }
    
    @objc private func handleBreakSkip() {
        // Skip the current break and start the next timer interval
        skipBreak()
    }
    
    // Add this method to get the current Pomodoro count
    func getPomodoroCount() -> Int {
        return pomodoroCount
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

import Cocoa

class MenuBarManager {
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    
    init() {
        setupMenuBar()
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
        }
    }
    
    func updateTimeRemaining(_ seconds: Int) {
        DispatchQueue.main.async {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            
            let timeString: String
            if minutes == 0 {
                timeString = String(format: "%ds", remainingSeconds)
            } else {
                timeString = String(format: "%d:%02d", minutes, remainingSeconds)
            }
            
            if let button = self.statusItem?.button {
                button.title = " \(timeString)"
            }
        }
    }
    
    func resetMenuBar() {
        DispatchQueue.main.async {
            if let button = self.statusItem?.button {
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
    
    func getStatusItem() -> NSStatusItem? {
        return statusItem
    }
} 
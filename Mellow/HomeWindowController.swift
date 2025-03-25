import Cocoa
import SwiftUI

class HomeWindowController: NSWindowController {
    
    convenience init<Content: View>(rootView: Content) {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 100),
            styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Set window properties
        window.isMovable = true
        window.isMovableByWindowBackground = false
        
        // Add beta tag to title
        let betaTag = NSTextField(labelWithString: "BETA")
        betaTag.font = .systemFont(ofSize: 10, weight: .medium)
        betaTag.textColor = .white
        betaTag.backgroundColor = NSColor(white: 1.0, alpha: 0.2)
        betaTag.isBezeled = false
        betaTag.isEditable = false
        betaTag.alignment = .center
        betaTag.frame = NSRect(x: window.frame.width - 60, y: window.frame.height - 28, width: 40, height: 18)
        betaTag.layer?.cornerRadius = 4
        betaTag.layer?.masksToBounds = true
        
        // Create the hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView
        
        // Add the beta tag to the titlebar
        if let titlebarView = window.standardWindowButton(.closeButton)?.superview?.superview {
            titlebarView.addSubview(betaTag)
        }
        
        self.init(window: window)
    }
    
    override func showWindow(_ sender: Any?) {
        window?.center()
        super.showWindow(sender)
        
        // Activate the app when showing the window
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func makeKeyAndOrderFront(_ sender: Any?) {
        window?.makeKeyAndOrderFront(sender)
    }
} 
import XCTest

class MellowUITests: XCTestCase {
    var app: XCUIApplication!
    var logFile: FileHandle?
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Create log file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logFileURL = documentsPath.appendingPathComponent("mellow_test_report.txt")
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        logFile = try FileHandle(forWritingTo: logFileURL)
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        try logFile?.close()
    }
    
    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        logFile?.write(logMessage.data(using: .utf8) ?? Data())
    }
    
    // MARK: - Menu Bar Tests
    
    func testMenuBarOptions() throws {
        log("Starting Menu Bar Tests")
        
        // Test status menu
        let statusMenu = app.menuBars.statusBars.buttons["Mellow"]
        XCTAssertTrue(statusMenu.exists)
        statusMenu.click()
        log("✓ Status menu opened successfully")
        
        // Test menu items
        let menuItems = [
            "Start Break",
            "Pause Break",
            "Stop Break",
            "Settings",
            "About",
            "Quit"
        ]
        
        for item in menuItems {
            let menuItem = app.menuItems[item]
            XCTAssertTrue(menuItem.exists)
            log("✓ Menu item '\(item)' found")
        }
        
        // Test menu item actions
        app.menuItems["Settings"].click()
        XCTAssertTrue(app.windows["Settings"].exists)
        log("✓ Settings window opened from menu")
        app.windows["Settings"].buttons["Close"].click()
        
        app.menuItems["About"].click()
        XCTAssertTrue(app.windows["About"].exists)
        log("✓ About window opened from menu")
        app.windows["About"].buttons["Close"].click()
        
        log("Menu Bar Tests Completed")
    }
    
    // MARK: - Card Tests
    
    func testPresetCards() throws {
        log("Starting Preset Cards Tests")
        
        let cards = [
            "20-20-20 Rule",
            "Pomodoro Technique",
            "Custom"
        ]
        
        for card in cards {
            log("Testing card: \(card)")
            
            // Find and click card
            let cardButton = app.buttons[card]
            XCTAssertTrue(cardButton.exists)
            cardButton.click()
            
            // Test card controls
            let startButton = app.buttons["Start"]
            let pauseButton = app.buttons["Pause"]
            let stopButton = app.buttons["Stop"]
            
            XCTAssertTrue(startButton.exists)
            startButton.click()
            log("✓ Start button clicked for \(card)")
            
            XCTAssertTrue(pauseButton.exists)
            pauseButton.click()
            log("✓ Pause button clicked for \(card)")
            
            XCTAssertTrue(stopButton.exists)
            stopButton.click()
            log("✓ Stop button clicked for \(card)")
            
            // Test blur view
            let blurView = app.otherElements["BreakOverlayView"]
            XCTAssertTrue(blurView.exists)
            log("✓ Blur view verified for \(card)")
            
            // Close blur view
            app.buttons["Skip"].click()
        }
        
        log("Preset Cards Tests Completed")
    }
    
    // MARK: - Settings Tests
    
    func testSettings() throws {
        log("Starting Settings Tests")
        
        // Open settings
        app.menuBars.statusBars.buttons["Mellow"].click()
        app.menuItems["Settings"].click()
        
        // Test general settings
        let generalTab = app.tabBars.buttons["General"]
        XCTAssertTrue(generalTab.exists)
        generalTab.click()
        
        // Test toggles
        let toggles = [
            "Start at Login",
            "Show in Menu Bar",
            "Enable Notifications",
            "Enable Sound Effects"
        ]
        
        for toggle in toggles {
            let toggleSwitch = app.switches[toggle]
            XCTAssertTrue(toggleSwitch.exists)
            toggleSwitch.click()
            log("✓ Toggle '\(toggle)' clicked")
        }
        
        // Test about section
        let aboutTab = app.tabBars.buttons["About"]
        XCTAssertTrue(aboutTab.exists)
        aboutTab.click()
        
        // Test about buttons
        let buttons = [
            "Check for Updates",
            "Visit Website",
            "Send Feedback"
        ]
        
        for button in buttons {
            let aboutButton = app.buttons[button]
            XCTAssertTrue(aboutButton.exists)
            log("✓ About button '\(button)' verified")
        }
        
        // Close settings
        app.windows["Settings"].buttons["Close"].click()
        
        log("Settings Tests Completed")
    }
    
    // MARK: - Custom Rules Tests
    
    func testCustomRules() throws {
        log("Starting Custom Rules Tests")
        
        // Open settings
        app.menuBars.statusBars.buttons["Mellow"].click()
        app.menuItems["Settings"].click()
        
        // Navigate to custom rules
        let customRulesTab = app.tabBars.buttons["Custom Rules"]
        XCTAssertTrue(customRulesTab.exists)
        customRulesTab.click()
        
        // Test sliders
        let sliders = [
            "Work Duration",
            "Break Duration",
            "Long Break Duration",
            "Sessions Until Long Break"
        ]
        
        for slider in sliders {
            let sliderElement = app.sliders[slider]
            XCTAssertTrue(sliderElement.exists)
            
            // Test slider interaction
            sliderElement.adjust(toNormalizedSliderPosition: 0.5)
            log("✓ Slider '\(slider)' adjusted")
        }
        
        // Test apply button
        let applyButton = app.buttons["Apply"]
        XCTAssertTrue(applyButton.exists)
        applyButton.click()
        log("✓ Apply button clicked")
        
        // Test close button
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.exists)
        closeButton.click()
        log("✓ Close button clicked")
        
        log("Custom Rules Tests Completed")
    }
    
    // MARK: - Blur View Tests
    
    func testBlurViews() throws {
        log("Starting Blur View Tests")
        
        let presets = [
            "20-20-20 Rule",
            "Pomodoro Technique",
            "Custom"
        ]
        
        for preset in presets {
            log("Testing blur view for: \(preset)")
            
            // Start break
            app.buttons[preset].click()
            app.buttons["Start"].click()
            
            // Verify blur view
            let blurView = app.otherElements["BreakOverlayView"]
            XCTAssertTrue(blurView.exists)
            
            // Test blur view elements
            let elements = [
                "Skip",
                "Timer",
                "Title",
                "Description"
            ]
            
            for element in elements {
                XCTAssertTrue(blurView.otherElements[element].exists)
                log("✓ Blur view element '\(element)' verified for \(preset)")
            }
            
            // Test escape key handling
            app.typeKey(.escape, modifierFlags: [])
            app.typeKey(.escape, modifierFlags: [])
            app.typeKey(.escape, modifierFlags: [])
            log("✓ Escape key handling tested for \(preset)")
            
            // Close blur view
            app.buttons["Skip"].click()
        }
        
        log("Blur View Tests Completed")
    }
    
    // MARK: - Main Test Suite
    
    func testMellowApp() throws {
        log("Starting Mellow UI Test Suite")
        log("=============================")
        
        try testMenuBarOptions()
        try testPresetCards()
        try testSettings()
        try testCustomRules()
        try testBlurViews()
        
        log("=============================")
        log("Mellow UI Test Suite Completed")
    }
} 
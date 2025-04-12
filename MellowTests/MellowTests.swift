//
//  MellowTests.swift
//  MellowTests
//
//  Created by Sriram P H on 1/8/25.
//

import Testing
@testable import Mellow

struct MellowTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func testPomodoroCount() async throws {
        let appDelegate = AppDelegate()
        
        // Start with Pomodoro technique
        appDelegate.startSelectedTechnique(technique: "Pomodoro Technique")
        
        // Verify initial count is 1
        try #expect(appDelegate.getPomodoroCount() == 1)
        
        // Simulate first work session completion (25 minutes)
        appDelegate.remainingTime = 0 // Force timer completion
        appDelegate.updateTimer() // Trigger timer update
        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait for 1 second for state updates
        
        // Verify count is now 2
        try #expect(appDelegate.getPomodoroCount() == 2)
        
        // Simulate second work session completion
        appDelegate.remainingTime = 0
        appDelegate.updateTimer()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify count is now 3
        try #expect(appDelegate.getPomodoroCount() == 3)
        
        // Simulate third work session completion
        appDelegate.remainingTime = 0
        appDelegate.updateTimer()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify count is now 4
        try #expect(appDelegate.getPomodoroCount() == 4)
        
        // Simulate fourth work session completion (should trigger long break)
        appDelegate.remainingTime = 0
        appDelegate.updateTimer()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify count resets to 1 after long break
        try #expect(appDelegate.getPomodoroCount() == 1)
        
        // Start second cycle
        appDelegate.remainingTime = 0
        appDelegate.updateTimer()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify count is now 2 in second cycle
        try #expect(appDelegate.getPomodoroCount() == 2)
        
        // Clean up
        appDelegate.stopTimer()
    }

}

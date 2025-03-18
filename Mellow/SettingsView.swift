import SwiftUI

struct SettingsView: View {
    @AppStorage("playSound") private var playSound = true
    @AppStorage("showOverlay") private var showOverlay = true
    @State private var launchAtLogin = false
    @State private var showQuitAlert = false
    let onClose: () -> Void
    @State private var isAppearing = false
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tabs for settings categories
            HStack(spacing: 0) {
                TabButton(title: "General", isSelected: selectedTab == 0) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = 0
                    }
                }
                
                TabButton(title: "Notifications", isSelected: selectedTab == 1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = 1
                    }
                }
                
                TabButton(title: "About", isSelected: selectedTab == 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = 2
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Divider()
                .padding(.top, 8)
            
            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0:
                        generalSettings
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    case 1:
                        notificationSettings
                            .transition(.asymmetric(
                                insertion: selectedTab > 1 ? .move(edge: .leading).combined(with: .opacity) : .move(edge: .trailing).combined(with: .opacity),
                                removal: selectedTab > 1 ? .move(edge: .leading).combined(with: .opacity) : .move(edge: .trailing).combined(with: .opacity)
                            ))
                    case 2:
                        aboutView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    default:
                        generalSettings
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
            }
            
            Divider()
            
            // Footer
            HStack {
                if showQuitAlert {
                    // Quit confirmation UI
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quit Mellow?")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("You'll need to restart manually")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Cancel") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showQuitAlert = false
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                        
                        Button("Quit") {
                            NSApplication.shared.terminate(nil)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                } else {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showQuitAlert = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                                .font(.system(size: 12))
                            Text("Quit Mellow")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showQuitAlert)
        }
        .frame(width: 320, height: 360)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            checkLaunchAtLogin()
            withAnimation(.easeOut(duration: 0.2)) {
                isAppearing = true
            }
        }
        .onDisappear {
            isAppearing = false
        }
        .onExitCommand {
            dismissSettings()
        }
        .keyboardShortcut(.escape, modifiers: [])
    }
    
    // General Settings Tab
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open at login")
                        .font(.system(size: 13, weight: .medium))
                    Text("Launch automatically when you log in")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .onChange(of: launchAtLogin) { oldValue, newValue in
                setLaunchAtLogin(newValue)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Countdown Overlay")
                        .font(.system(size: 13, weight: .medium))
                    Text("Show 10-second countdown before break")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $showOverlay)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            Spacer()
        }
    }
    
    // Notification Settings Tab
    private var notificationSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Play sounds")
                        .font(.system(size: 13, weight: .medium))
                    Text("Signal the start and end of breaks")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $playSound)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            Spacer()
        }
    }
    
    // About Tab
    private var aboutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 12) {
                Image("MellowLogo")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mellow")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Version 1.0.0")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 8)
            
            Text("Mellow helps you maintain better eye health and productive work habits through timed breaks.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            
            Button("Check for Updates") {
                NSWorkspace.shared.open(URL(string: "macappstore://apps.apple.com/app/id6740374516?mt=12")!)
                dismissSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("Share Feedback") {
                NSWorkspace.shared.open(URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSfQ1g2pwtErgAGpbmlxqJpPM7Yc0nDmAERLyBZzZHn3zSHQVw/viewform?usp=sharing")!)
                dismissSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
            
            Spacer()
        }
    }
    
    private func dismissSettings() {
        withAnimation(.easeIn(duration: 0.2)) {
            isAppearing = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onClose()
        }
    }
    
    private func checkLaunchAtLogin() {
        // Check if app is set to launch at login
        // This would use the actual implementation for your app
        launchAtLogin = false // Replace with actual implementation
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        // Implementation to set launch at login status
        // This would use the actual implementation for your app
    }
}

// Tab Button component for the settings view
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("\(title) Tab")
        .help("\(title) Settings")
    }
}

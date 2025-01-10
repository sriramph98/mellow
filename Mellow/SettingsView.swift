import SwiftUI

struct SettingsView: View {
    @AppStorage("playSound") private var playSound = true
    @State private var launchAtLogin = false
    let onClose: () -> Void
    @State private var isAppearing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with close button
            HStack {
                Text("Settings")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: dismissSettings) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
            }
            
            // Settings List
            VStack(alignment: .leading, spacing: 24) {
                // Launch Setting
                SettingRow(
                    title: "Open at login",
                    description: "Launch Mellow automatically when you log in.",
                    isEnabled: $launchAtLogin
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Sound Setting
                SettingRow(
                    title: "Enable Sound",
                    description: "Play sounds to signal the start and end of breaks.",
                    isEnabled: $playSound
                )
            }
            
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0, green: 0, blue: 0).opacity(0.3))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isAppearing ? 1 : 0)
        .scaleEffect(isAppearing ? 1 : 0.95)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                isAppearing = true
            }
            launchAtLogin = getLaunchAtLoginStatus()
        }
        .onChange(of: launchAtLogin) { oldValue, newValue in
            setLaunchAtLogin(newValue)
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
    
    private func getLaunchAtLoginStatus() -> Bool {
        return LaunchAtLogin.isEnabled()
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLogin.setEnabled(enabled)
    }
}

struct SettingRow: View {
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    private let accentColor = Color(red: 0/255, green: 122/255, blue: 255/255)  // #007AFF
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(2)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .accentColor(accentColor)
                .padding(.leading, 48)
                .environment(\.colorScheme, .dark)
        }
    }
}

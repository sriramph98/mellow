import SwiftUI
import ApplicationServices

struct AccessibilityBlurView: View {
    var body: some View {
        WindowBlurView(style: .primary)
            .ignoresSafeArea()
    }
}

struct AccessibilityOverlayView: View {
    let onEnableAccessibility: () -> Void
    @State private var hasPermission = false
    @State private var isVisible = true
    
    // Timer to check permission status
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        withAnimation(.easeOut(duration: 0.3)) {
            self.hasPermission = hasPermission
            self.isVisible = !hasPermission
        }
    }
    
    var body: some View {
        ZStack {
            // Background blur
            AccessibilityBlurView()
            
            // Content
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                
                // Text content
                VStack(spacing: 12) {
                    Text("Accessibility Permission Required")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Mellow needs accessibility permission to show break reminders above other windows.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                
                // Button
                Button(action: onEnableAccessibility) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 16, weight: .medium))
                        Text("Enable Accessibility")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            checkAccessibilityPermission()
        }
        .onReceive(timer) { _ in
            // Always check permission status to handle both granting and revoking
            checkAccessibilityPermission()
        }
    }
}

#Preview {
    AccessibilityOverlayView(onEnableAccessibility: {})
        .frame(width: 600, height: 400)
        .background(Color.black)
} 
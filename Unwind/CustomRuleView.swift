import SwiftUI

struct CustomRuleView: View {
    @AppStorage("reminderInterval") private var reminderInterval = 1200
    @AppStorage("breakDuration") private var breakDuration = 20
    let onSave: (TimeInterval) -> Void
    let onClose: () -> Void
    @State private var isAppearing = false
    
    private var breakDurationInMinutes: Binding<Double> {
        Binding(
            get: { Double(breakDuration) / 60.0 },
            set: { breakDuration = Int($0 * 60) }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with close button
            HStack {
                Text("Custom Break")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: dismissSettings) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
            }
            
            // Settings content
            VStack(alignment: .leading, spacing: 24) {
                // Break Interval Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Break Interval")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("How often should we remind you to take a break?")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .lineSpacing(2)
                    
                    HStack(spacing: 16) {
                        Slider(
                            value: Binding(
                                get: { Double(reminderInterval) / 60.0 },
                                set: { reminderInterval = Int($0 * 60) }
                            ),
                            in: 1...60
                        )
                        .tint(Color(nsColor: .controlAccentColor))
                        .frame(width: 200)
                        
                        Text("\(Int(Double(reminderInterval) / 60.0)) min")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.top, 8)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Break Duration Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Break Duration")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("How long should each break last?")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .lineSpacing(2)
                    
                    HStack(spacing: 16) {
                        Slider(
                            value: breakDurationInMinutes,
                            in: 0.5...10
                        )
                        .tint(Color(nsColor: .controlAccentColor))
                        
                        Text(String(format: "%.1f min", Double(breakDuration) / 60.0))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.top, 8)
                }
            }
            
            Spacer(minLength: 16)
            
            // Apply button at bottom right
            HStack {
                Spacer()
                
                Button(action: saveAndClose) {
                    Text("Apply")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                .buttonStyle(PillButtonStyle())  // Using the same style as home window
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.8))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isAppearing ? 1 : 0)
        .scaleEffect(isAppearing ? 1 : 0.95)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                isAppearing = true
            }
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
    
    private func saveAndClose() {
        onSave(TimeInterval(reminderInterval))
        dismissSettings()
    }
}

#Preview {
    CustomRuleView(
        onSave: { _ in },
        onClose: {}
    )
    .frame(height: 240)
    .background(.background)
}

#Preview("Dark Mode") {
    CustomRuleView(
        onSave: { _ in },
        onClose: {}
    )
    .frame(height: 240)
    .background(.background)
    .preferredColorScheme(.dark)
} 
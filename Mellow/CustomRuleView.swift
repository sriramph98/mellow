import SwiftUI
import AppKit

struct CustomRuleView: View {
    @AppStorage("reminderInterval") private var reminderInterval = 1200
    @AppStorage("breakDuration") private var breakDuration = 20
    let onSave: (TimeInterval) -> Void
    let onClose: () -> Void
    @State private var isAppearing = false
    @FocusState private var isEditingBreakDuration: Bool
    @FocusState private var isEditingInterval: Bool
    @State private var tempBreakDurationText = ""
    @State private var tempIntervalText = ""
    
    private var breakDurationInMinutes: Binding<Double> {
        Binding(
            get: { Double(breakDuration) / 60.0 },
            set: { breakDuration = Int($0 * 60) }
        )
    }
    
    // Create a custom accent color
    private let accentColor = Color(red: 0/255, green: 122/255, blue: 255/255)  // #007AFF
    
    // Add helper function to format and validate time input
    private func parseTimeInput(_ input: String) -> Int? {
        let components = input.components(separatedBy: ":")
        if components.count == 2,
           let minutes = Int(components[0]),
           let seconds = Int(components[1]),
           minutes >= 0, minutes <= 30,
           seconds >= 0, seconds < 60 {
            return minutes * 60 + seconds
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with close button
            HStack {
                Text("Custom Rule")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
            }
            
            // Settings List
            VStack(alignment: .leading, spacing: 24) {
                // Break Interval Setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Break Interval")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Enhanced time control with buttons
                        HStack(spacing: 8) {
                            Button(action: {
                                let newValue = max(60, reminderInterval - 60)
                                withAnimation(.spring(response: 0.3)) {
                                    reminderInterval = newValue
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(reminderInterval <= 60)
                            .opacity(reminderInterval <= 60 ? 0.3 : 1)
                            
                            Text(formatTime(reminderInterval))
                                .font(.system(size: 17, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                            
                            Button(action: {
                                let newValue = min(7200, reminderInterval + 60)
                                withAnimation(.spring(response: 0.3)) {
                                    reminderInterval = newValue
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(reminderInterval >= 7200)
                            .opacity(reminderInterval >= 7200 ? 0.3 : 1)
                        }
                    }
                    
                    Text("How often should we remind you to take a break?")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                    
                    // Slider with range labels
                    VStack(spacing: 4) {
                        ZStack {
                            CustomSlider(range: 1...120, value: Binding(
                                get: { Double(reminderInterval) / 60.0 },
                                set: { reminderInterval = Int($0 * 60) }
                            ))
                            .frame(height: 20)
                            .contentShape(Rectangle())
                        }
                        
                        // Labels for min/max
                        HStack {
                            Text("1m")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.8))
                            
                            Spacer()
                            
                            Text("2h")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .contentShape(Rectangle())
                .background(Color.clear)
                
                Divider()
                
                // Break Duration Setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Break Duration")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Enhanced time control with buttons
                        HStack(spacing: 8) {
                            Button(action: {
                                let newValue = max(15, breakDuration - 15)
                                withAnimation(.spring(response: 0.3)) {
                                    breakDuration = newValue
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(breakDuration <= 15)
                            .opacity(breakDuration <= 15 ? 0.3 : 1)
                            
                            Text(formatTime(breakDuration))
                                .font(.system(size: 17, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                            
                            Button(action: {
                                let newValue = min(600, breakDuration + 15)
                                withAnimation(.spring(response: 0.3)) {
                                    breakDuration = newValue
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(breakDuration >= 600)
                            .opacity(breakDuration >= 600 ? 0.3 : 1)
                        }
                    }
                    
                    Text("How long should each break last?")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                    
                    // Slider with range labels
                    VStack(spacing: 4) {
                        ZStack {
                            CustomSlider(range: 0.25...10, value: breakDurationInMinutes)
                                .frame(height: 20)
                                .contentShape(Rectangle())
                        }
                        
                        // Labels for min/max
                        HStack {
                            Text("15s")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.8))
                            
                            Spacer()
                            
                            Text("10m")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .contentShape(Rectangle())
                .background(Color.clear)
            }
            .contentShape(Rectangle())
            
            Spacer()
            
            // Apply Button
            Button(action: {
                onSave(TimeInterval(reminderInterval))
            }) {
                Text("Apply")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0/255, green: 122/255, blue: 255/255))
                            .shadow(color: Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.4), radius: 4, x: 0, y: 2)
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(width: 360)
        .background(
            ZStack {
                CustomBlurView(style: .primary)
                    .opacity(isAppearing ? 1 : 0)
            }
        )
        .onAppear {
            withAnimation(
                .spring(
                    response: 0.3,
                    dampingFraction: 0.65,
                    blendDuration: 0
                )
            ) {
                isAppearing = true
            }
        }
    }
    
    private func formatTime(_ time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02dm %02ds", minutes, seconds)
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
    .frame(height: 640)
    .background(.background)
    .preferredColorScheme(.dark)
} 

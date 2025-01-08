import SwiftUI

struct CustomRuleView: View {
    @AppStorage("reminderInterval") private var reminderInterval = 1200
    @AppStorage("breakDuration") private var breakDuration = 20
    let onSave: (TimeInterval) -> Void
    
    private var breakDurationInMinutes: Binding<Double> {
        Binding(
            get: { Double(breakDuration) / 60.0 },
            set: { breakDuration = Int($0 * 60) }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Custom Break Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                // Reminder Interval Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Break Interval")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        Slider(
                            value: Binding(
                                get: { Double(reminderInterval) / 60.0 },
                                set: { reminderInterval = Int($0 * 60) }
                            ),
                            in: 1...60
                        )
                        .frame(width: 160)
                        
                        Text("\(Int(Double(reminderInterval) / 60.0)) min")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                
                // Break Duration Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Break Duration")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        Slider(
                            value: breakDurationInMinutes,
                            in: 0.5...10  // 30 seconds to 10 minutes
                        )
                        .frame(width: 160)
                        
                        Text(String(format: "%.1f min", Double(breakDuration) / 60.0))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Apply") {
                    onSave(TimeInterval(reminderInterval))
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "Custom Rule" }) {
                        window.close()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(.windowBackground)
    }
}

#Preview {
    CustomRuleView { _ in }
} 
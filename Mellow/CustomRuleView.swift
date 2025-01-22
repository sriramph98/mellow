import SwiftUI
import AppKit

struct CustomSlider: NSViewRepresentable {
    let range: ClosedRange<Double>
    @Binding var value: Double
    private let accentColor = NSColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0)  // #007AFF
    
    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, 
                            minValue: range.lowerBound, 
                            maxValue: range.upperBound, 
                            target: context.coordinator, 
                            action: #selector(Coordinator.valueChanged(_:)))
        
        // Force dark appearance
        slider.appearance = NSAppearance(named: .darkAqua)
        
        // Configure slider appearance
        slider.trackFillColor = accentColor
        slider.isEnabled = true
        slider.isContinuous = true
        
        // Set to linear style without tick marks
        slider.sliderType = .linear
        slider.controlSize = .regular
        slider.numberOfTickMarks = 0
        
        // Ensure the slider is properly layered
        slider.wantsLayer = true
        slider.layer?.zPosition = 1
        
        return slider
    }
    
    func updateNSView(_ nsView: NSSlider, context: Context) {
        // Snap to nearest 30-second interval
        let valueInSeconds = nsView.doubleValue * 60
        let snappedSeconds = round(valueInSeconds / 30) * 30
        let snappedValue = snappedSeconds / 60
        
        if value != snappedValue {
            DispatchQueue.main.async {
                value = snappedValue
            }
        }
        
        nsView.doubleValue = snappedValue
        nsView.trackFillColor = accentColor
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let slider: CustomSlider
        
        init(_ slider: CustomSlider) {
            self.slider = slider
        }
        
        @objc func valueChanged(_ sender: NSSlider) {
            // Snap to nearest 30-second interval
            let valueInSeconds = sender.doubleValue * 60
            let snappedSeconds = round(valueInSeconds / 30) * 30
            let snappedValue = snappedSeconds / 60
            
            slider.value = snappedValue
        }
    }
}

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
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
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
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(formatTime(reminderInterval))
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .monospacedDigit()
                    }
                    
                    Text("How often should we remind you to take a break?")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                    
                    CustomSlider(range: 1...120, value: Binding(
                        get: { Double(reminderInterval) / 60.0 },
                        set: { reminderInterval = Int($0 * 60) }
                    ))
                    .frame(height: 20)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Break Duration Setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Break Duration")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(formatTime(breakDuration))
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .monospacedDigit()
                    }
                    
                    Text("How long should each break last?")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                    
                    CustomSlider(range: 0.5...30, value: breakDurationInMinutes)
                        .frame(height: 20)
                }
            }
            
            Spacer()
            
            // Apply Button
            Button(action: {
                onSave(TimeInterval(reminderInterval))
            }) {
                Text("Apply")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(PillButtonStyle(customBackground: accentColor))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(width: 360)
        .background(
            VisualEffectView(material: .dark, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .opacity(isAppearing ? 1 : 0)
        .scaleEffect(isAppearing ? 1 : 0.98)
        .offset(y: isAppearing ? 0 : -10)
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

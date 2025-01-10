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
        
        // Set to linear style with tick marks
        slider.sliderType = .linear
        slider.controlSize = .regular
        slider.numberOfTickMarks = 5
        slider.allowsTickMarkValuesOnly = false
        slider.tickMarkPosition = .below
        
        // Ensure the slider is properly layered
        slider.wantsLayer = true
        slider.layer?.zPosition = 1
        
        return slider
    }
    
    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.doubleValue = value
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
            slider.value = sender.doubleValue
        }
    }
}

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
    
    // Create a custom accent color
    private let accentColor = Color(red: 0/255, green: 122/255, blue: 255/255)  // #007AFF
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Header with close button
            HStack {
                Text("Custom Rule")
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
            
            // Settings content
            VStack(alignment: .leading, spacing: 48) {
                // Break Interval Section
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Break Interval")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("How often should we remind you to take a break?")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(spacing: 8) {
                        CustomSlider(
                            range: 1...60,
                            value: Binding(
                                get: { Double(reminderInterval) / 60.0 },
                                set: { reminderInterval = Int($0 * 60) }
                            )
                        )
                        .frame(height: 20)
                        
                        Text(String(format: "%02dm %02ds", 
                             Int(reminderInterval) / 60,  // Minutes
                             Int(reminderInterval) % 60   // Seconds
                        ))
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                // Break Duration Section
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Break Duration")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("How long should each break last?")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(spacing: 8) {
                        CustomSlider(
                            range: 0.5...10,
                            value: breakDurationInMinutes
                        )
                        .frame(height: 20)
                        
                        Text(String(format: "%02dm %02ds", 
                             Int(breakDuration) / 60,     // Minutes
                             Int(breakDuration) % 60      // Seconds
                        ))
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            
            Spacer()
            
            // Apply button
            HStack {
                Spacer()
                Button(action: saveAndClose) {
                    Text("Apply")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                .buttonStyle(PillButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
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
    .frame(height: 640)
    .background(.background)
    .preferredColorScheme(.dark)
} 

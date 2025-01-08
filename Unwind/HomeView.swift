import SwiftUI

struct PresetCard: View {
    let title: String
    let isSelected: Bool
    let description: String
    let action: () -> Void
    let isCustom: Bool
    let onModify: (() -> Void)?
    
    init(
        title: String,
        isSelected: Bool,
        description: String,
        action: @escaping () -> Void,
        isCustom: Bool = false,
        onModify: (() -> Void)? = nil
    ) {
        self.title = title
        self.isSelected = isSelected
        self.description = description
        self.action = action
        self.isCustom = isCustom
        self.onModify = onModify
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: action) {
                VStack(spacing: 16) {
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            if isCustom {
                Button("Modify") {
                    onModify?()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.bottom, 8)
            }
        }
        .frame(width: 180, height: 240)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray.opacity(0.2))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.blue, lineWidth: 2)
                    }
                }
        }
    }
}

struct HomeView: View {
    let timeInterval: TimeInterval
    let onTimeIntervalChange: (TimeInterval) -> Void
    @State private var selectedPreset: String = "20-20-20"
    @State private var isRunning = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Unwind")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            HStack(spacing: 24) {
                PresetCard(
                    title: "20-20-20",
                    isSelected: selectedPreset == "20-20-20",
                    description: "Every 20 minutes, look at something 20 feet away for 20 seconds",
                    action: {
                        selectedPreset = "20-20-20"
                        onTimeIntervalChange(1200)
                    }
                )
                
                PresetCard(
                    title: "Pomodoro",
                    isSelected: selectedPreset == "Pomodoro",
                    description: "Work for 25 minutes, then take a 5-minute break",
                    action: {
                        selectedPreset = "Pomodoro"
                        onTimeIntervalChange(1500)
                    }
                )
                
                PresetCard(
                    title: "Custom",
                    isSelected: selectedPreset == "Custom",
                    description: "Set your own break interval",
                    action: {
                        selectedPreset = "Custom"
                    },
                    isCustom: true,
                    onModify: {
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                            appDelegate.showCustomRuleSettings()
                        }
                    }
                )
            }
            .padding(.horizontal, 40)
            
            HStack(spacing: 20) {
                Button(isRunning ? "Stop" : "Start") {
                    isRunning.toggle()
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        if isRunning {
                            appDelegate.startSelectedTechnique(technique: selectedPreset)
                        } else {
                            appDelegate.stopTimer()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                
                Button("Preview") {
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        appDelegate.showBlurScreen(forTechnique: selectedPreset)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .font(.system(size: 16, weight: .medium, design: .rounded))
            }
            
            Spacer()
            
            Text("Close this window to minimize to menu bar")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
        .background(Color(NSColor.windowBackgroundColor))
        .edgesIgnoringSafeArea(.all)
    }
} 
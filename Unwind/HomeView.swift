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
                .buttonStyle(PillButtonStyle())
                .font(.system(size: 14, weight: .medium, design: .rounded))
            }
        }
        .frame(width: 200, height: 260)
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

struct PillButtonStyle: ButtonStyle {
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 10) {
            configuration.label
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 8)
        .frame(width: 135, alignment: .center)
        .background(isHovering ? .black.opacity(0.8) : .white.opacity(0.14))
        .animation(.smooth(duration: 0.2), value: isHovering)
        .cornerRadius(999)
        .onHover { hovering in
            withAnimation {
                isHovering = hovering
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
        VStack(spacing: 40) {
            VStack(spacing: 8) {
                Text("Unwind")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Because breaks power brilliance")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(.top, 40)
            
            HStack(spacing: 32) {
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
            .padding(.horizontal, 50)
            
            HStack(spacing: 20) {
                Button {
                    isRunning.toggle()
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        if isRunning {
                            appDelegate.startSelectedTechnique(technique: selectedPreset)
                        } else {
                            appDelegate.stopTimer()
                        }
                    }
                } label: {
                    Text(isRunning ? "Stop" : "Start")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                .buttonStyle(PillButtonStyle())
                
                Button {
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        appDelegate.showBlurScreen(forTechnique: selectedPreset)
                    }
                } label: {
                    Text("Preview")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                .buttonStyle(PillButtonStyle())
            }
            .padding(.top, 20)
            
            Spacer()
            
            Text("Close this window to minimize to menu bar")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 30)
        .background(Color(NSColor.windowBackgroundColor))
        .edgesIgnoringSafeArea(.all)
    }
} 
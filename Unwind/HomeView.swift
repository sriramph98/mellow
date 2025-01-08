import SwiftUI

struct PresetCard: View {
    let title: String
    let isSelected: Bool
    let description: String
    let action: () -> Void
    let isCustom: Bool
    let onModify: (() -> Void)?
    let isDisabled: Bool
    
    init(
        title: String,
        isSelected: Bool,
        description: String,
        action: @escaping () -> Void,
        isCustom: Bool = false,
        onModify: (() -> Void)? = nil,
        isDisabled: Bool = false
    ) {
        self.title = title
        self.isSelected = isSelected
        self.description = description
        self.action = action
        self.isCustom = isCustom
        self.onModify = onModify
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
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
            .opacity(isDisabled ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct PillButtonStyle: ButtonStyle {
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 10) {
            configuration.label
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minWidth: 135, alignment: .center)
        .background(isHovering ? .black.opacity(0.3) : .white.opacity(0.14))
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
    @StateObject private var timerState: TimerState
    @State private var selectedPreset: String = "20-20-20"
    @State private var isRunning = false
    
    init(
        timeInterval: TimeInterval,
        timerState: TimerState,
        onTimeIntervalChange: @escaping (TimeInterval) -> Void
    ) {
        self.timeInterval = timeInterval
        self._timerState = StateObject(wrappedValue: timerState)
        self.onTimeIntervalChange = onTimeIntervalChange
    }
    
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
                    },
                    isDisabled: isRunning && selectedPreset != "20-20-20"
                )
                
                PresetCard(
                    title: "Pomodoro",
                    isSelected: selectedPreset == "Pomodoro",
                    description: "Work for 25 minutes, then take a 5-minute break",
                    action: {
                        selectedPreset = "Pomodoro"
                        onTimeIntervalChange(1500)
                    },
                    isDisabled: isRunning && selectedPreset != "Pomodoro"
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
                    },
                    isDisabled: isRunning && selectedPreset != "Custom"
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
                    HStack(spacing: 8) {
                        if isRunning {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text(timerState.timeString)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .monospacedDigit()
                        } else {
                            Text("Start")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                    }
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
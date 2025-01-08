import SwiftUI

struct PresetCard: View {
    let title: String
    let isSelected: Bool
    let description: String
    let action: () -> Void
    let isCustom: Bool
    let onModify: (() -> Void)?
    let isDisabled: Bool
    let namespace: Namespace.ID
    @State private var isHovering = false
    
    init(
        title: String,
        isSelected: Bool,
        description: String,
        action: @escaping () -> Void,
        isCustom: Bool = false,
        onModify: (() -> Void)? = nil,
        isDisabled: Bool = false,
        namespace: Namespace.ID
    ) {
        self.title = title
        self.isSelected = isSelected
        self.description = description
        self.action = action
        self.isCustom = isCustom
        self.onModify = onModify
        self.isDisabled = isDisabled
        self.namespace = namespace
    }
    
    private var iconName: (normal: String, selected: String) {
        switch title {
        case "20-20-20":
            return ("20-normal", "20-selected")  // Your custom PNG names
        case "Pomodoro":
            return ("pomodoro-normal", "pomodoro-selected")
        case "Custom":
            return ("custom-normal", "custom-selected")
        default:
            return ("default-normal", "default-selected")
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    Image(isSelected ? iconName.selected : iconName.normal)
                        .resizable()
                        .interpolation(.medium)
                        .antialiased(true)
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .opacity(isSelected ? 1 : 0.7)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.smooth(duration: 0.2), value: isSelected)
                    
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
                    .fill(backgroundGradient)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(nsColor: NSColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)), lineWidth: 2)
                                .matchedGeometryEffect(id: "selectedCard", in: namespace)
                        }
                    }
            }
            .opacity(isDisabled ? 0.4 : 1.0)
            .scaleEffect(isSelected || isHovering ? 1.02 : 1.0)
            .animation(.smooth(duration: 0.3), value: isSelected)
            .animation(.smooth(duration: 0.2), value: isHovering)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            guard !isDisabled else { return }
            isHovering = hovering
        }
    }
    
    private var backgroundGradient: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                Color(nsColor: NSColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 0.4))  // #007AFF with 40% opacity
            )
        } else if isHovering {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        .white.opacity(0.15),
                        .white.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(.gray.opacity(0.2))
        }
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
    @Namespace private var animation
    
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
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Unwind")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Because breaks power brilliance")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(.top, 24)
            
            HStack(spacing: 24) {
                PresetCard(
                    title: "20-20-20",
                    isSelected: selectedPreset == "20-20-20",
                    description: "Every 20 minutes, look at something 20 feet away for 20 seconds",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPreset = "20-20-20"
                            onTimeIntervalChange(1200)
                        }
                    },
                    isDisabled: isRunning && selectedPreset != "20-20-20",
                    namespace: animation
                )
                
                PresetCard(
                    title: "Pomodoro",
                    isSelected: selectedPreset == "Pomodoro",
                    description: "Work for 25 minutes, then take a 5-minute break",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPreset = "Pomodoro"
                            onTimeIntervalChange(1500)
                        }
                    },
                    isDisabled: isRunning && selectedPreset != "Pomodoro",
                    namespace: animation
                )
                
                PresetCard(
                    title: "Custom",
                    isSelected: selectedPreset == "Custom",
                    description: "Set your own break interval",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPreset = "Custom"
                        }
                    },
                    isCustom: true,
                    onModify: {
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                            appDelegate.showCustomRuleSettings()
                        }
                    },
                    isDisabled: isRunning && selectedPreset != "Custom",
                    namespace: animation
                )
            }
            .padding(.horizontal, 32)
            
            HStack(spacing: 16) {
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
                
                if isRunning {
                    Button {
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                            appDelegate.skipBreak()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                            Text("Reset")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(PillButtonStyle())
                    .transition(
                        AnyTransition.scale.combined(with: .opacity)
                            .animation(.smooth(duration: 0.3))
                    )
                }
                
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
            .padding(.top, 16)
            
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "menubar.arrow.up.rectangle")
                        .font(.system(size: 14))
                    Text("Unwind lives in your menu bar")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                
                Text("Click the timer icon in the menu bar to access Unwind anytime")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .padding(.vertical, 24)
        .frame(idealWidth: 800)
        .fixedSize(horizontal: false, vertical: true)
        .preferredColorScheme(nil)
    }
} 
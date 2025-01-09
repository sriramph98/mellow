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
    
    private var sfSymbol: (normal: String, selected: String) {
        switch title {
        case "20-20-20 Rule":
            return ("eyes.inverse", "eyes")  // Eye symbol for 20-20-20 rule
        case "Pomodoro Technique":
            return ("clock", "clock.fill")  // Timer for Pomodoro
        case "Custom":
            return ("slider.horizontal.below.square.filled.and.square", "slider.horizontal.below.square.and.square.filled")  // Slider for custom settings
        default:
            return ("clock", "clock.fill")
        }
    }
    
    private var cardStyle: (background: Color, opacity: Double, stroke: Color) {
        if isSelected {
            return (
                .accentColor,
                0.15,  // Subtle but visible when selected
                .accentColor.opacity(0.8)
            )
        } else if isHovering {
            return (
                .white,
                0.08,  // Subtle hover state
                .clear
            )
        } else {
            return (
                .white,
                0.05,  // Subtle base state
                .clear
            )
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    Image(systemName: isSelected ? sfSymbol.selected : sfSymbol.normal)
                        .font(.system(size: 48))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? Color.accentColor : .white)
                        .opacity(isSelected ? 1 : 0.9)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.smooth(duration: 0.2), value: isSelected)
                    
                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
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
                    .fill(cardStyle.background.opacity(cardStyle.opacity))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(cardStyle.stroke, lineWidth: 1)
                                .matchedGeometryEffect(id: "selectedCard", in: namespace)
                        }
                    }
            }
            .opacity(isDisabled ? 0.4 : 1.0)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.smooth(duration: 0.3).delay(0.05), value: isSelected)
            .animation(.smooth(duration: 0.2), value: isHovering)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            guard !isDisabled else { return }
            withAnimation(.smooth(duration: 0.2)) {
                isHovering = hovering
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
    @State private var selectedPreset: String = "20-20-20 Rule"
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
            VStack(spacing: 16) {
                Image("UnwindLogo")
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: 80, height: 80)
                
                Text("Unwind")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.top, 24)
            
            HStack(spacing: 24) {
                PresetCard(
                    title: "20-20-20 Rule",
                    isSelected: selectedPreset == "20-20-20 Rule",
                    description: "Every 20 minutes, look 20 feet away for 20 seconds.",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPreset = "20-20-20 Rule"
                            onTimeIntervalChange(1200)
                        }
                    },
                    isDisabled: isRunning && selectedPreset != "20-20-20 Rule",
                    namespace: animation
                )
                
                PresetCard(
                    title: "Pomodoro Technique",
                    isSelected: selectedPreset == "Pomodoro Technique",
                    description: "Work in focused 25-minute sessions.",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPreset = "Pomodoro Technique"
                            onTimeIntervalChange(1500)
                        }
                    },
                    isDisabled: isRunning && selectedPreset != "Pomodoro Technique",
                    namespace: animation
                )
                
                PresetCard(
                    title: "Custom",
                    isSelected: selectedPreset == "Custom",
                    description: "Customize to match your workflow and stay productive on your terms.",
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
                .frame(width: 135, alignment: isRunning ? .trailing : .center)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isRunning)
                
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
            }
            .padding(.top, 16)
            .animation(.smooth(duration: 0.3), value: isRunning)
            
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "menubar.arrow.up.rectangle")
                        .font(.system(size: 14))
                    Text("Unwind lives in your menu bar")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                
                Text("Click the icon in the menu bar to access Unwind anytime")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .padding(.vertical, 24)
        .frame(idealWidth: 800)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    HomeView(
        timeInterval: 1200,
        timerState: TimerState(),
        onTimeIntervalChange: { _ in }
    )
    .frame(width: 800, height: 600)
    .background(Color.black.opacity(0.8))
}

struct PresetCardPreview: View {
    @Namespace private var namespace
    
    var body: some View {
        PresetCard(
            title: "20-20-20 Rule",
            isSelected: true,
            description: "Every 20 minutes, look 20 feet away for 20 seconds.",
            action: {},
            namespace: namespace
        )
        .frame(width: 250)
        .background(Color.black.opacity(0.8))
        .padding()
    }
}

#Preview("Preset Card") {
    PresetCardPreview()
} 

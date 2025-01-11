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
                .black,
                0.3,  // Darker tint when selected
                .clear
            )
        } else if isHovering {
            return (
                .black,
                0.2,  // Darker hover state
                .clear
            )
        } else {
            return (
                .black,
                0.15,  // Darker base state
                .clear
            )
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 24) {
                // Icon
                Image(systemName: isSelected ? sfSymbol.selected : sfSymbol.normal)
                    .font(.system(size: 32))  // Slightly smaller for horizontal layout
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? .white : .white)
                    .opacity(isSelected ? 1 : 0.9)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isCustom && isSelected {
                    Button(action: { onModify?() }) {
                        Image(systemName: "gearshape.circle.fill")
                            .font(.system(size: 18))  // Slightly larger for better visibility
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)  // Reduced horizontal padding
                            
                    }
                    .buttonStyle(PillButtonStyle(minWidth: 0))  // Remove minimum width
                    .frame(height: 30)  // Fixed height for consistency
                }
            }
            .padding(24)
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
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.smooth(duration: 0.3).delay(0.05), value: isSelected)
    }
}

struct HomeView: View {
    let timeInterval: TimeInterval
    let onTimeIntervalChange: (TimeInterval) -> Void
    @StateObject private var timerState: TimerState
    @State private var selectedPreset: String = "20-20-20 Rule"
    @State private var isRunning = false
    @State private var isFooterVisible = false
    @State private var isContentVisible = false  // Add state for main content animation
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
        VStack(spacing: 24) {
            // Main content group (everything except footer)
            VStack(spacing: 24) {
                // App Header
                HStack(spacing: 12) {
                    Image("MellowLogo")
                        .resizable()
                        .frame(width: 32, height: 32)
                    
                    Text("Mellow")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Preset Cards with 16px spacing
                VStack(spacing: 16) {
                    PresetCard(
                        title: "20-20-20 Rule",
                        isSelected: selectedPreset == "20-20-20 Rule",
                        description: "Take a 20-second break every 20 minutes to look at something 20 feet away.",
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
                        description: "Focus for 25 minutes, then take a 5-minute break to stay productive.",
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
                        description: "Set your own break intervals and durations to match your workflow.",
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPreset = "Custom"
                                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                    onTimeIntervalChange(appDelegate.customInterval)
                                }
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
                .padding(.horizontal, 24)
                
                // Buttons section
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isRunning.toggle()
                        }
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                            if isRunning {
                                appDelegate.startSelectedTechnique(technique: selectedPreset)
                            } else {
                                appDelegate.stopTimer()
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isRunning {
                                Image(systemName: "stop.circle.fill")
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
                    .buttonStyle(PillButtonStyle(
                        minWidth: 135,
                        customBackground: isRunning ? Color(red: 1, green: 0, blue: 0).opacity(0.8) : nil
                    ))
                    .frame(width: 135, alignment: isRunning ? .trailing : .center)
                    
                    // Preview button (temporarily hidden)
                    /*
                    Button(action: {
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                            appDelegate.showBlurScreen(forTechnique: selectedPreset)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.system(size: 12, weight: .medium))
                            Text("Preview")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(isRunning)
                    */
                    
                    if isRunning {
                        Button(action: {
                            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                appDelegate.skipBreak()
                            }
                        }) {
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
                            .asymmetric(
                                insertion: .scale(scale: 0.8)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(x: -20)),
                                removal: .scale(scale: 0.8)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(x: -20))
                            )
                        )
                    }
                }
                .padding(.horizontal, 32)
                .animation(
                    .spring(
                        response: 0.4,
                        dampingFraction: 0.8,
                        blendDuration: 0
                    ),
                    value: isRunning
                )
            }
            .blur(radius: isContentVisible ? 0 : 10)
            .opacity(isContentVisible ? 1 : 0)
            .scaleEffect(isContentVisible ? 1 : 0.8)
            
            Spacer().frame(height: 8)
            
            // Cloud image and footer
            ZStack(alignment: .bottom) {
                Image("cloud")
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 480)
                    .opacity(0.8)
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
                
                // Footer section
                HStack {
                    // Left - Menu bar info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "menubar.dock.rectangle")
                                .font(.system(size: 13))
                                .foregroundColor(.black.opacity(0.6))
                            
                            Text("Mellow lives in the menu bar")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(.black.opacity(0.6))
                        }
                        
                        Text("Click the icon in the menu to access Mellow")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(.black.opacity(0.4))
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Right side - Settings icon
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.black.opacity(0.5))
                        .onTapGesture {
                            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                appDelegate.showSettings()
                            }
                        }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .offset(y: isFooterVisible ? 0 : 100)
            .opacity(isFooterVisible ? 1 : 0)
            .blur(radius: isFooterVisible ? 0 : 10)
        }
        .padding(.top, 24)
        .frame(minWidth: 700)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            Rectangle()
                .foregroundColor(.clear)
                .background(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color(red: 0.4, green: 0.75, blue: 1).opacity(0.8), location: 0.00),
                            Gradient.Stop(color: .white.opacity(0.8), location: 1.00),
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 0.72)
                    )
                )
        )
        .onAppear {
            // Animate content first, then footer
            withAnimation(.easeOut(duration: 1.0)) {
                isContentVisible = true
            }
            
            // Slight delay for footer animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 1.0)) {
                    isFooterVisible = true
                }
            }
        }
    }
}

#Preview {
    HomeView(
        timeInterval: 1200,
        timerState: TimerState(),
        onTimeIntervalChange: { _ in }
    )
    .frame(width: 800, height: 600)
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

import SwiftUI
import Combine

struct BlurView: View {
    let technique: String
    @State private var timeRemaining: Int
    @State private var timer: Timer.TimerPublisher = Timer.publish(every: 1, on: .main, in: .common)
    @State private var timerSubscription: AnyCancellable?
    @State private var opacity: Double = 0
    
    init(technique: String) {
        self.technique = technique
        
        // Set initial time based on technique
        let initialTime: Int
        switch technique {
        case "20-20-20":
            initialTime = 20
        case "Pomodoro":
            initialTime = 300
        case "Custom":
            initialTime = UserDefaults.standard.integer(forKey: "breakDuration")
        default:
            initialTime = 60
        }
        
        _timeRemaining = State(initialValue: initialTime)
    }
    
    var instructionText: String {
        switch technique {
        case "20-20-20":
            return "Look at something 20 feet away"
        case "Pomodoro":
            return "Take a refreshing break"
        case "Custom":
            return "Time for your custom break"
        default:
            return "Take a break"
        }
    }
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text(technique)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(instructionText)
                    .font(.system(size: 24, design: .rounded))
                    .foregroundColor(.white)
                
                Text(formatTime(timeRemaining))
                    .font(.system(size: 40, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                if technique == "20-20-20" {
                    Image(systemName: "eye")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                } else if technique == "Pomodoro" {
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                
                Button("Skip") {
                    timerSubscription?.cancel()
                    withAnimation(.easeOut(duration: 0.3)) {
                        opacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                            appDelegate.dismissBlurScreen()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 16, weight: .medium, design: .rounded))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }
            
            timerSubscription = timer.autoconnect().sink { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                }
            }
        }
        .onDisappear {
            timerSubscription?.cancel()
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
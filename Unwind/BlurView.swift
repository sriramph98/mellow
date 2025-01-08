import SwiftUI
import Combine

struct BlurView: View {
    @State private var timeRemaining = 60
    @State private var timer: Timer.TimerPublisher = Timer.publish(every: 1, on: .main, in: .common)
    @State private var timerSubscription: AnyCancellable?
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background blur
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("Take a Break")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Relax for a minute")
                    .font(.system(size: 24, design: .rounded))
                    .foregroundColor(.white)
                
                Text("\(timeRemaining)s")
                    .font(.system(size: 40, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        opacity = 0
                    }
                    timerSubscription?.cancel()
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
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 1
            }
            timeRemaining = 60
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
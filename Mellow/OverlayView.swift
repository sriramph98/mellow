import SwiftUI

struct OverlayView: View {
    @State private var timeRemaining: TimeInterval = 10
    @Binding var isAnimatingOut: Bool
    @State var isAppearing = false
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let progressTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var progress: Double = 1.0
    let onComplete: () -> Void
    let initialTimeRemaining: TimeInterval
    
    init(isAnimatingOut: Binding<Bool>, initialTimeRemaining: TimeInterval = 10, onComplete: @escaping () -> Void) {
        self._isAnimatingOut = isAnimatingOut
        self.onComplete = onComplete
        self.initialTimeRemaining = initialTimeRemaining
        self._timeRemaining = State(initialValue: initialTimeRemaining)
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Top section with dismiss button
                HStack {
                    // Mellow title with icon
                    HStack(spacing: 4) {
                        Image("menuBarIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 17, height: 17)
                        Text("Mellow")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.leading, 24)
                    
                    Spacer()
                    ZStack {
                        // Timeout circle
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 24, height: 24)
                        
                        // X mark button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isAnimatingOut = true
                            }
                            (NSApplication.shared.delegate as? AppDelegate)?.overlayDismissed = true
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                }
                
                // Content section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Break starts in")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(Int(timeRemaining))s")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                Spacer()
                
                // Bottom section with buttons
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isAnimatingOut = true
                            }
                            // Skip and restart timer
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                    appDelegate.overlayDismissed = true
                                    appDelegate.nextBreakTime = Date().addingTimeInterval(appDelegate.timeInterval)
                                    // Create and start timer
                                    let newTimer = Timer(fire: Date(), interval: 0.5, repeats: true) { [weak appDelegate] _ in
                                        appDelegate?.updateTimer()
                                    }
                                    RunLoop.main.add(newTimer, forMode: .common)
                                    appDelegate.timer = newTimer
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "forward")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Skip")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.white)
                        }
                        .buttonStyle(PillButtonStyle(
                            customBackground: Color.white.opacity(0.2)
                        ))
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isAnimatingOut = true
                            }
                            onComplete()
                        }) {
                            Text("Take Break Now")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PillButtonStyle(
                            customBackground: Color.white.opacity(0.2)
                        ))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining = max(0, timeRemaining - 0.5)
            }
            if timeRemaining <= 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isAnimatingOut = true
                }
                // Ensure onComplete is called after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }
        }
        .onReceive(progressTimer) { _ in
            withAnimation(.linear(duration: 0.1)) {
                progress = max(0, Double(timeRemaining) / initialTimeRemaining)
            }
        }
        .onAppear {
            isAppearing = true
        }
        .opacity(isAnimatingOut ? 0 : 1)
        .blur(radius: isAnimatingOut ? 10 : 0)
        .animation(.easeInOut(duration: 0.3), value: isAnimatingOut)
    }
}

#Preview {
    OverlayView(
        isAnimatingOut: .constant(false),
        initialTimeRemaining: 10,
        onComplete: {}
    )
    .frame(width: 360)
    .background(Color.black)
} 

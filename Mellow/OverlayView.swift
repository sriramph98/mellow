import SwiftUI

struct OverlayView: View {
    let technique: String
    @State private var timeRemaining: TimeInterval = 10
    @Binding var isAnimatingOut: Bool
    @State var isAppearing = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let progressTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var progress: Double = 1.0
    let onComplete: () -> Void
    
    private var breakDescription: String {
        switch technique {
        case "20-20-20 Rule":
            return "20 second eye break"
        case "Pomodoro Technique":
            return "5 minute break"
        case "Custom":
            return "break"
        default:
            return "break"
        }
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Top section with dismiss button
                HStack {
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isAnimatingOut = true
                                isAppearing = false
                            }
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
                    Text("\(breakDescription) starts in")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(Int(timeRemaining))s")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                // Bottom section with buttons
                HStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isAnimatingOut = true
                                isAppearing = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Skip")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PillButtonStyle(
                            customBackground: Color.white.opacity(0.2)
                        ))
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isAnimatingOut = true
                                isAppearing = false
                            }
                            onComplete()
                        }) {
                            Text("Take Break Now")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
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
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
            if timeRemaining <= 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isAnimatingOut = true
                    isAppearing = false
                }
                onComplete()
            }
        }
        .onReceive(progressTimer) { _ in
            withAnimation(.linear(duration: 0.1)) {
                progress = max(0, Double(timeRemaining) / 10.0)
            }
        }
        .onAppear {
            isAppearing = false
            withAnimation(
                .spring(
                    response: 0.3,
                    dampingFraction: 0.65,
                    blendDuration: 0
                )
            ) {
                isAppearing = true
            }
        }
        .opacity(isAppearing ? 1 : 0)
    }
} 
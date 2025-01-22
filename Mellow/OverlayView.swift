import SwiftUI

struct OverlayView: View {
    @State private var timeRemaining: TimeInterval = 10
    @Binding var isAnimatingOut: Bool
    @State var isAppearing = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let progressTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var progress: Double = 1.0
    let onComplete: () -> Void
    
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isAnimatingOut = true
                                isAppearing = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "forward.fill")
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
                                isAppearing = false
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

#Preview {
    OverlayView(
        isAnimatingOut: .constant(false),
        onComplete: {}
    )
    .frame(width: 360)
    .background(Color.black)
} 

import SwiftUI

/// A custom slider with snapping behavior and enhanced styling
struct CustomSlider: View {
    let range: ClosedRange<Double>
    @Binding var value: Double
    
    var body: some View {
        // Use GeometryReader to create a more custom appearance
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 6)
                
                // Filled portion
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0/255, green: 122/255, blue: 255/255))
                    .frame(width: max(0, min(geometry.size.width * (value - range.lowerBound) / (range.upperBound - range.lowerBound), geometry.size.width)), height: 6)
                
                // Custom thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .offset(x: max(0, min(geometry.size.width * (value - range.lowerBound) / (range.upperBound - range.lowerBound), geometry.size.width)) - 8)
                
                // Invisible drag area (larger than visible components for easier interaction)
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 30)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let width = geometry.size.width
                                let ratio = min(max(0, gesture.location.x / width), 1)
                                let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * ratio
                                
                                // Apply snapping to 30-second intervals
                                let valueInSeconds = newValue * 60
                                let snappedSeconds = round(valueInSeconds / 30) * 30
                                let snappedValue = snappedSeconds / 60
                                
                                value = max(range.lowerBound, min(range.upperBound, snappedValue))
                            }
                    )
            }
        }
        .frame(height: 30)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: value)
    }
} 
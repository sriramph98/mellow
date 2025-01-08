import SwiftUI

struct SettingsView: View {
    let timeInterval: TimeInterval
    let onTimeIntervalChange: (TimeInterval) -> Void
    
    var body: some View {
        Form {
            Picker("Break Interval", selection: .init(
                get: { timeInterval },
                set: { onTimeIntervalChange($0) }
            )) {
                Text("20 minutes").tag(TimeInterval(1200))
                Text("30 minutes").tag(TimeInterval(1800))
                Text("45 minutes").tag(TimeInterval(2700))
                Text("60 minutes").tag(TimeInterval(3600))
            }
        }
        .padding()
        .frame(width: 300, height: 200)
    }
} 
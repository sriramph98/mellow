import SwiftUI

struct HomeView: View {
    let timeInterval: TimeInterval
    let onTimeIntervalChange: (TimeInterval) -> Void
    @State private var selectedInterval: TimeInterval
    @State private var showingAdvancedSettings = false
    
    init(timeInterval: TimeInterval, onTimeIntervalChange: @escaping (TimeInterval) -> Void) {
        self.timeInterval = timeInterval
        self.onTimeIntervalChange = onTimeIntervalChange
        _selectedInterval = State(initialValue: timeInterval)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "timer")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Break Timer")
                .font(.title)
                .bold()
            
            Text("Take regular breaks to reduce eye strain")
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Break Interval")
                    .font(.headline)
                
                Picker("", selection: Binding(
                    get: { selectedInterval },
                    set: { 
                        selectedInterval = $0
                        onTimeIntervalChange($0)
                    }
                )) {
                    Text("20 minutes").tag(TimeInterval(1200))
                    Text("30 minutes").tag(TimeInterval(1800))
                    Text("45 minutes").tag(TimeInterval(2700))
                    Text("60 minutes").tag(TimeInterval(3600))
                }
                .pickerStyle(.segmented)
            }
            .padding()
            
            Button("Preview Break Screen") {
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    appDelegate.showBlurScreen()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Advanced Settings") {
                showingAdvancedSettings.toggle()
            }
            .sheet(isPresented: $showingAdvancedSettings) {
                AdvancedSettingsView()
            }
            
            Spacer()
            
            Text("Close this window to minimize to menu bar")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 400)
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("playSound") private var playSound = true
    @AppStorage("showNotifications") private var showNotifications = true
    
    var body: some View {
        Form {
            Toggle("Play Sound", isOn: $playSound)
            Toggle("Show Notifications", isOn: $showNotifications)
        }
        .padding()
        .frame(width: 300, height: 200)
    }
} 
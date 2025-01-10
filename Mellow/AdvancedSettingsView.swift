import SwiftUI

struct AdvancedSettingsView: View {
    @AppStorage("playSound") private var playSound = true
    @AppStorage("showNotifications") private var showNotifications = true
    
    var body: some View {
        Form {
            GroupBox(label: Text("App Settings").bold()) {
                Toggle("Play sound effect", isOn: $playSound)
                Toggle("Show notification", isOn: $showNotifications)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 300)
        .fixedSize()
    }
}


import SwiftUI

struct CustomRuleView: View {
    @State private var reminderInterval: Double
    @State private var breakDuration: Double
    let onIntervalChange: (TimeInterval) -> Void
    
    init(onIntervalChange: @escaping (TimeInterval) -> Void) {
        self.onIntervalChange = onIntervalChange
        let savedReminderInterval = UserDefaults.standard.integer(forKey: "reminderInterval")
        let savedBreakDuration = UserDefaults.standard.integer(forKey: "breakDuration")
        
        _reminderInterval = State(initialValue: savedReminderInterval > 0 ? Double(savedReminderInterval) / 60.0 : 20.0)
        _breakDuration = State(initialValue: savedBreakDuration > 0 ? Double(savedBreakDuration) / 60.0 : 1.0)
    }
    
    var body: some View {
        Form {
            GroupBox(label: Text("Custom Rule").bold()) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Remind after every")
                        HStack {
                            TextField("", value: $reminderInterval, formatter: NumberFormatter())
                                .frame(width: 60)
                            Text("minutes")
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Break for")
                        HStack {
                            TextField("", value: $breakDuration, formatter: NumberFormatter())
                                .frame(width: 60)
                            Text("minutes")
                        }
                    }
                }
                .onChange(of: reminderInterval) { _, newValue in
                    let seconds = Int(newValue * 60)
                    UserDefaults.standard.set(seconds, forKey: "reminderInterval")
                    onIntervalChange(TimeInterval(seconds))
                }
                .onChange(of: breakDuration) { _, newValue in
                    let seconds = Int(newValue * 60)
                    UserDefaults.standard.set(seconds, forKey: "breakDuration")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 300)
        .fixedSize()
    }
} 
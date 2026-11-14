import SwiftUI
import UserNotifications
#if os(iOS) && canImport(AlarmKit)
import AlarmKit
#endif

enum ThoughtAlertKind: String, Identifiable {
    case reminder, alarm
    var id: Self { self }
    var title: String { self == .alarm ? "Set alarm" : "Remind me" }
}

struct ThoughtAlertView: View {
    let thought: MaxThought
    let kind: ThoughtAlertKind
    @State private var date = Date.now.addingTimeInterval(300)
    @State private var result: String?
    @State private var working = false
    @State private var alarmID: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Text(thought.title)
            #if os(watchOS)
            Text(date, format: .dateTime.day().month().hour().minute())
            Button("5 minutes later") { date = date.addingTimeInterval(300) }
            Button("5 minutes earlier") {
                date = max(Date.now.addingTimeInterval(60), date.addingTimeInterval(-300))
            }
            #else
            DatePicker("When", selection: $date, in: Date.now...)
            #endif
            if let result { Text(result) }
            if alarmID == nil {
                Button(kind.title) { Task { await schedule() } }.disabled(working)
            }
            Button("Done") { dismiss() }.disabled(working)
        }
    }

    @MainActor
    private func schedule() async {
        guard !working else { return }
        working = true
        defer { working = false }
        guard date > Date.now else {
            result = "Choose a time in the future."
            return
        }
        do {
            let id = UUID()
            if kind == .alarm {
                #if os(iOS) && canImport(AlarmKit)
                guard #available(iOS 26.0, *), !ProcessInfo.processInfo.isiOSAppOnMac else {
                    result = "Alarms aren’t available on this device."
                    return
                }
                let manager = AlarmManager.shared
                guard try await manager.requestAuthorization() == .authorized else {
                    result = "Allow alarms for Max in Settings to schedule one."
                    return
                }
                let presentation = AlarmPresentation(alert: .init(
                    title: LocalizedStringResource("Max thought alarm"),
                    stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill")
                ))
                let attributes = AlarmAttributes(presentation: presentation, metadata: ThoughtAlarmMetadata(), tintColor: .cyan)
                let configuration = AlarmManager.AlarmConfiguration(
                    schedule: .fixed(date), attributes: attributes, sound: .default
                )
                _ = try await manager.schedule(id: id, configuration: configuration)
                #else
                result = "Alarms aren’t available on this device."
                return
                #endif
            } else {
                let center = UNUserNotificationCenter.current()
                guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                    result = "Allow notifications for Max in Settings to schedule a reminder."
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = "Max thought reminder"
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
                try await center.add(.init(identifier: id.uuidString, content: content, trigger: trigger))
            }
            alarmID = id
            let when = date.formatted(date: .abbreviated, time: .shortened)
            result = "\(kind == .alarm ? "Alarm" : "Reminder") set for \(when) on this device."
        } catch {
            result = "Max couldn’t schedule this \(kind.rawValue)."
        }
    }
}

#if os(iOS) && canImport(AlarmKit)
@available(iOS 26.0, *)
private struct ThoughtAlarmMetadata: AlarmMetadata {}
#endif

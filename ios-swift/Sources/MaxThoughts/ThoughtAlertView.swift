import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ThoughtAlertView: View {
    @ObservedObject var store: ThoughtStore
    let thoughtID: UUID
    let title: String
    let standalone: Bool
    let kind: ThoughtAlertKind
    let scope: String
    @State private var date = Date.now.addingTimeInterval(300)
    @State private var result: String?
    @State private var working = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var permissionMissing = false

    @State private var alarmLabel = ""

    init(store: ThoughtStore, thought: MaxThought, kind: ThoughtAlertKind, scope: String) {
        self.init(store: store, thoughtID: thought.id, title: thought.title, kind: kind, scope: scope, standalone: false)
    }

    init(store: ThoughtStore, thoughtID: UUID, title: String, kind: ThoughtAlertKind, scope: String, standalone: Bool) {
        self.store = store
        self.thoughtID = thoughtID
        self.title = title
        self.kind = kind
        self.scope = scope
        self.standalone = standalone
    }

    private var scheduled: ScheduledThoughtAlert? {
        store.alert(for: thoughtID, kind: kind)
    }

    var body: some View {
        NavigationStack {
            Form {
                if standalone && scheduled == nil {
                    TextField("Alarm name", text: $alarmLabel)
                        .disabled(working)
                } else {
                    Text(scheduled?.label ?? title)
                }
                if let scheduled {
                    LabeledContent("Scheduled on this device", value: scheduled.date.formatted(date: .abbreviated, time: .shortened))
                    Button("Cancel \(kind.rawValue)", role: .destructive) {
                        do {
                            try store.cancelAlert(scheduled)
                            result = "\(kind.name) cancelled."
                        } catch { result = "Max couldn’t cancel this \(kind.rawValue)." }
                    }
                } else {
                    #if os(watchOS)
                    Text(date, format: .dateTime.day().month().hour().minute())
                    Button("1 hour later") { date = date.addingTimeInterval(3600) }
                    Button("5 minutes later") { date = date.addingTimeInterval(300) }
                    Button("5 minutes earlier") {
                        date = max(Date.now.addingTimeInterval(60), date.addingTimeInterval(-300))
                    }
                    #else
                    DatePicker("When", selection: $date, in: Date.now...)
                        .disabled(working)
                    #endif
                    Button(kind.title) { Task { await schedule() } }.disabled(working)
                }
                if let result { Text(result) }
                if working { ProgressView("Scheduling…") }
                #if os(iOS)
                if permissionMissing {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                #endif
            }
            .navigationTitle(kind.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(working) }
            }
        }
        .interactiveDismissDisabled(working)
        .task(id: scheduled?.id) { checkAlarm() }
    }

    private func checkAlarm() {
        guard !working, let scheduled, kind == .alarm else { return }
        do {
            if try !ThoughtAlertScheduler.hasAlarm(id: scheduled.id) {
                try store.cancelAlert(scheduled)
                result = "This alarm is no longer scheduled. Choose a new time to set it again."
            }
        } catch ThoughtAlertError.alarmPermission {
            permissionMissing = true
            result = ThoughtAlertError.alarmPermission.localizedDescription
        } catch {
            result = "Max couldn’t verify this alarm in iOS."
        }
    }

    @MainActor
    private func schedule() async {
        guard !working else { return }
        working = true
        defer { working = false }
        result = nil
        permissionMissing = false
        do {
            let name = alarmLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = standalone ? (name.isEmpty ? title : String(name.prefix(80))) : nil
            try await store.scheduleAlert(for: thoughtID, kind: kind, date: date, scope: scope, label: label)
            result = "\(kind.name) set for \(date.formatted(date: .abbreviated, time: .shortened))."
        } catch let error as ThoughtAlertError {
            switch error {
            case .alarmPermission, .notificationPermission: permissionMissing = true
            default: break
            }
            result = error.localizedDescription
        } catch {
            result = "Max couldn’t schedule this \(kind.rawValue)."
        }
    }
}

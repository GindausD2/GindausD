import SwiftUI

struct ThoughtAlertView: View {
    @ObservedObject var store: ThoughtStore
    let thought: MaxThought
    let kind: ThoughtAlertKind
    let scope: String
    @State private var date = Date.now.addingTimeInterval(300)
    @State private var result: String?
    @State private var working = false
    @Environment(\.dismiss) private var dismiss

    private var scheduled: ScheduledThoughtAlert? {
        store.alert(for: thought.id, kind: kind)
    }

    var body: some View {
        Form {
            Text(thought.title)
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
            Button("Done") { dismiss() }.disabled(working)
        }
        .interactiveDismissDisabled(working)
    }

    @MainActor
    private func schedule() async {
        guard !working else { return }
        working = true
        defer { working = false }
        result = nil
        do {
            try await store.scheduleAlert(for: thought.id, kind: kind, date: date, scope: scope)
        } catch let error as ThoughtAlertError {
            result = error.localizedDescription
        } catch {
            result = "Max couldn’t schedule this \(kind.rawValue)."
        }
    }
}

import Combine
import SwiftUI

struct NextUpCard: View {
    let account: String
    @Environment(\.scenePhase) private var scenePhase
    @State private var reminder: Reminder?
    @State private var meeting: LifeEvent?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Group {
            if let reminder {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Next Up", systemImage: "bell")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "#315E73"))
                    Text(reminder.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                    if !reminder.body.isEmpty { Text(reminder.body).font(.caption).lineLimit(2) }
                    Text(reminder.fireDate, format: .dateTime.weekday().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                    if let meeting {
                        Text("Saved meeting · \(meeting.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 20) { actions(for: reminder) }
                        VStack(alignment: .leading) { actions(for: reminder) }
                    }
                    .buttonStyle(.borderless)
                    .disabled(busy)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .glassCard(cornerRadius: 20)
            }
        }
        .onAppear(perform: reload)
        .onChange(of: account) { _, _ in reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
        .onReceive(NotificationCenter.default.publisher(for: ReminderNotifications.changed)) { _ in reload() }
        .alert("Reminder couldn’t be updated", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
    }

    @ViewBuilder private func actions(for reminder: Reminder) -> some View {
        Button("Done") {
            if !ReminderActions.complete(reminder, scope: account) { error = "Reopen the reminder and try again." }
            reload()
        }
        Button("Remind me in 10 min") {
            busy = true
            Task {
                let failure = await ReminderActions.reschedule(reminder, to: Date().addingTimeInterval(600), scope: account)
                if StorageService.shared.accountScope == account { error = failure }
                busy = false
                reload()
            }
        }
    }

    private func reload() {
        let store = StorageService.shared
        guard store.accountScope == account else { reminder = nil; meeting = nil; return }
        let open = store.loadReminders().filter {
            $0.completedAt == nil && ($0.triggerKind == nil || $0.triggerKind == "time")
        }
        reminder = open.min { $0.fireDate == $1.fireDate ? $0.id < $1.id : $0.fireDate < $1.fireDate }
        meeting = reminder?.followUpMeetingID.flatMap { id in
            store.usesSavedMemory ? store.loadLifeEvents().first { $0.id == id } : nil
        }
    }
}

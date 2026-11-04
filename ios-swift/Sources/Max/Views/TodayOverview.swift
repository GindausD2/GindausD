import SwiftUI
import EventKit
import Combine

@MainActor
struct TodayOverview: View {
    @ObservedObject private var auth = AuthService.shared
    @State private var scope = ""
    @State private var day = StorageService.dayKey()
    @State private var priorities: [DailyPriority] = []
    @State private var reminders: [Reminder] = []
    @State private var priorityText = ""
    @State private var nextEvent: String?
    @State private var calendarNotice = "Connect your calendar to see the next appointment."
    @State private var rescheduling: Reminder?
    @State private var error: String?
    private let storage = StorageService.shared

    var body: some View {
        Group {
            Section("Next appointment") {
                if let nextEvent { Text(nextEvent) }
                else { Text(calendarNotice).foregroundStyle(.secondary) }
                if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
                    Button("Connect calendar") {
                        Task { @MainActor in
                            let granted = (try? await EKEventStore().requestFullAccessToEvents()) ?? false
                            guard storage.accountScope == scope else { return }
                            if granted { reload() } else { calendarNotice = "Calendar access was not granted. You can allow it in iPhone Settings." }
                        }
                    }
                }
            }
            Section("Your three priorities") {
                ForEach(priorities) { priority in
                    HStack {
                        Button {
                            guard let index = priorities.firstIndex(where: { $0.id == priority.id }) else { return }
                            priorities[index].completed.toggle(); savePriorities()
                        } label: { Label(priority.title, systemImage: priority.completed ? "checkmark.circle.fill" : "circle") }
                        .buttonStyle(.borderless)
                        Spacer()
                        Button(role: .destructive) { priorities.removeAll { $0.id == priority.id }; savePriorities() } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless).accessibilityLabel("Remove priority \(priority.title)")
                    }
                }
                if priorities.count < 3 {
                    HStack {
                        TextField("One thing that matters today", text: $priorityText).onSubmit(addPriority)
                        Button("Add", action: addPriority).disabled(priorityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            Section("Unfinished reminders") {
                if reminders.isEmpty { Text("You're up to date. Add a reminder with the plus button.").foregroundStyle(.secondary) }
                ForEach(reminders) { reminder in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(reminder.title).font(.headline)
                        Text(reminder.triggerSummary(place: storage.loadPlaceVisits().first { $0.id == reminder.placeID })).font(.subheadline).foregroundStyle(.secondary)
                        if reminder.triggerKind != "context", reminder.triggerKind != "location", reminder.fireDate < Date() {
                            Text("Overdue · still unfinished").font(.caption).foregroundStyle(.orange)
                        }
                        HStack {
                            Button("Complete") {
                                guard ReminderActions.complete(reminder, scope: scope) else { error = "Your reminder changed. Please reopen Your day."; return }
                                reload()
                            }
                            Spacer()
                            Button("Reschedule") { rescheduling = reminder }
                        }.buttonStyle(.borderless)
                    }.padding(.vertical, 6)
                }
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }
        .onAppear { if scope.isEmpty { scope = storage.accountScope }; reload() }
        .onChange(of: auth.currentUser) { _, _ in reload() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in reload() }
        .sheet(item: $rescheduling, onDismiss: reload) { reminder in ReminderRescheduleView(reminder: reminder, scope: scope) }
    }

    private func reload() {
        guard storage.accountScope == scope else { priorities = []; reminders = []; nextEvent = nil; calendarNotice = "Your account changed. Reopen Your day."; return }
        day = StorageService.dayKey()
        priorities = storage.loadPriorities(day: day)
        reminders = storage.loadReminders().filter { $0.completedAt == nil }.sorted { $0.fireDate < $1.fireDate }
        nextEvent = nil
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { calendarNotice = "Calendar is not connected. Allow access in iPhone Settings to see appointments."; return }
        let store = EKEventStore(), now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        let events = store.events(matching: store.predicateForEvents(withStart: now, end: end, calendars: nil))
            .filter { !$0.isAllDay && $0.endDate > now }.sorted { $0.startDate < $1.startDate }
        if let event = events.first {
            let formatter = DateFormatter(); formatter.dateStyle = .none; formatter.timeStyle = .short
            nextEvent = "\(event.title ?? "Appointment") · \(formatter.string(from: event.startDate))"
        } else { calendarNotice = "No upcoming timed appointments today." }
    }

    private func addPriority() {
        guard day == StorageService.dayKey(), priorities.count < 3 else { reload(); return }
        let title = priorityText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 160 else { error = "Keep each priority under 160 characters."; return }
        priorities.append(DailyPriority(title: title, day: day)); savePriorities(); priorityText = ""
    }
    private func savePriorities() {
        guard day == StorageService.dayKey(), storage.savePriorities(priorities, day: day, accountScope: scope) else { error = "Your account or day changed. Reopen Your day."; reload(); return }
        error = nil
    }
}

struct ReminderRescheduleView: View {
    let reminder: Reminder
    let scope: String
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date().addingTimeInterval(3600)
    @State private var saving = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Text(reminder.title).font(.headline)
                DatePicker("New time", selection: $date, in: Date()...)
                Text(TimeZone.current.identifier).font(.caption)
                if reminder.triggerKind == "location" || reminder.triggerKind == "context" { Text("Saving replaces the arrival or context trigger with this time.").font(.caption) }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Reschedule")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saving ? "Saving…" : "Confirm time") {
                            saving = true
                            Task { @MainActor in
                                error = await ReminderActions.reschedule(reminder, to: date, scope: scope)
                                saving = false
                                if error == nil { dismiss() }
                            }
                        }.disabled(saving)
                    }
                }
        }.interactiveDismissDisabled(saving).tint(Color(hex: "#315E73"))
    }
}

import SwiftUI
import EventKit

struct LifeMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthService.shared
    @State private var scope = ""
    @State private var events: [LifeEvent] = []
    @State private var query = ""
    @State private var editing: LifeEvent?
    @State private var calendarCandidates: [LifeEvent] = []
    @State private var notice: String?
    @State private var loading = false
    private let store = StorageService.shared
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Search people, places or topics. Planned meetings do not prove attendance.").font(.caption).foregroundStyle(.secondary)
                    if !store.usesSavedMemory { Text("Memory is paused. Existing events can be inspected or forgotten; turn memory on to add or update them.").font(.caption) }
                    Button("Review past calendar meetings") { loadCalendar() }.disabled(loading || !store.usesSavedMemory)
                }
                if let notice { Section { Text(notice).foregroundStyle(.secondary) } }
                if !calendarCandidates.isEmpty {
                    Section("Calendar candidates · not saved") {
                        ForEach(calendarCandidates) { event in
                            Button { editing = event } label: { VStack(alignment: .leading) { Text(event.title); Text(event.occurredAt, style: .date).font(.caption) } }
                        }
                    }
                }
                Section("Your timeline") {
                    let matches = LifeEvent.matching(events, query: query)
                    if matches.isEmpty { Text("No matching memories. Save a meeting or review a calendar entry.").foregroundStyle(.secondary) }
                    ForEach(matches) { event in
                        Button { editing = event } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(event.title).font(.headline)
                                if !event.person.isEmpty { Text(event.person) }
                                Text(event.occurredAt, style: .date).font(.caption)
                                if !event.place.isEmpty { Text(event.place).font(.subheadline) }
                                Text(event.attended ? "Attendance confirmed by you" : "Planned · attendance not confirmed").font(.caption).foregroundStyle(.secondary)
                                Text("Source: \(event.source)").font(.caption).foregroundStyle(.secondary)
                            }
                        }.foregroundStyle(.primary)
                    }
                }
            }.navigationTitle("Life Memory")
                .searchable(text: $query, prompt: "Person, place or topic")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button { editing = LifeEvent(title: "", person: "", place: "", occurredAt: Date(), notes: "") } label: { Image(systemName: "plus") }.disabled(!store.usesSavedMemory).accessibilityLabel("Add life memory") }
                }
                .onAppear { if scope.isEmpty { scope = store.accountScope }; reload() }
                .onChange(of: auth.currentUser) { _, _ in reload() }
                .sheet(item: $editing, onDismiss: reload) { event in
                    LifeEventEditor(event: event, scope: scope, existing: events.contains { $0.id == event.id }) { _ in
                        calendarCandidates.removeAll { $0.id == event.id }; editing = nil
                    }
                }
        }.tint(Color(hex: "#315E73"))
    }
    private func reload() {
        guard store.accountScope == scope else { events = []; calendarCandidates = []; editing = nil; notice = "Your account changed. Reopen Life Memory."; return }
        events = store.loadLifeEvents()
    }
    private func loadCalendar() {
        loading = true; notice = nil
        let expected = scope
        Task { @MainActor in
            defer { loading = false }
            let calendar = EKEventStore()
            guard (try? await calendar.requestFullAccessToEvents()) == true else { notice = "Calendar access was not granted. You can allow it in iPhone Settings."; return }
            guard store.accountScope == expected, store.usesSavedMemory else { return }
            let end = Date(), start = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date().addingTimeInterval(-180 * 86400)
            let entries = calendar.events(matching: calendar.predicateForEvents(withStart: start, end: end, calendars: nil))
                .filter { !$0.isAllDay && $0.startDate <= end }.sorted { $0.startDate > $1.startDate }
            calendarCandidates = entries.prefix(50).map { event in
                var candidate = LifeEvent(title: String((event.title ?? "Calendar meeting").prefix(160)), person: String((event.attendees ?? []).compactMap(\.name).joined(separator: ", ").prefix(200)), place: String((event.location ?? "").prefix(300)), occurredAt: event.startDate, notes: String((event.notes ?? "").prefix(2000)))
                candidate.source = "Calendar entry reviewed by you"
                candidate.sourceExcerpt = String("\(event.title ?? "Calendar meeting") · \(ISO8601DateFormatter().string(from: event.startDate)) · \(event.location ?? "No location listed")".prefix(2000))
                return candidate
            }
            notice = entries.isEmpty ? "No timed calendar entries found in the past six months." : "Showing up to 50 recent entries. Select one to review and save. Calendar information may be incomplete."
        }
    }
}

struct LifeEventEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var event: LifeEvent
    let scope: String
    var existing = false
    let onFinish: (String?) -> Void
    @State private var error: String?
    @State private var forget = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Review the details") {
                    TextField("Meeting or event", text: $event.title)
                    TextField("People you met", text: $event.person)
                    TextField("Place", text: $event.place)
                    DatePicker("When", selection: $event.occurredAt)
                    Text(TimeZone.current.identifier).font(.caption)
                    TextEditor(text: $event.notes).frame(minHeight: 90).accessibilityLabel("What you discussed")
                    Toggle("I confirm this meeting happened", isOn: $event.attended)
                    Text("Leave this off for a planned meeting. Max must not claim you attended it.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Supporting source") {
                    Text(event.source)
                    Text(event.sourceExcerpt).font(.caption).textSelection(.enabled)
                    Text("Calendar details are a snapshot, not a live attendance record. Saved corrections are based on your review.").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if existing { Section { Button("Forget this event", role: .destructive) { forget = true } } }
            }.navigationTitle(existing ? "Edit life memory" : "Review life memory")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onFinish(nil); dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            event.updatedAt = Date()
                            if StorageService.shared.saveLifeEvent(event, scope: scope, replacing: existing) { onFinish(event.id); dismiss() }
                            else { error = "Check the details, memory setting and account. Deleted events cannot be restored by an old editor." }
                        }.disabled(!event.isValid)
                    }
                }
                .confirmationDialog("Forget this event?", isPresented: $forget) {
                    Button("Forget event", role: .destructive) {
                        if StorageService.shared.forgetLifeEvent(id: event.id, scope: scope) { onFinish(nil); dismiss() }
                        else { error = "Your account or event changed." }
                    }
                } message: { Text("This removes the saved event from future memory searches. Existing chat history and the original calendar entry are separate.") }
        }.tint(Color(hex: "#315E73"))
    }
}

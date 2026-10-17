import SwiftUI
import UserNotifications

/// Local V1 features remain usable before an AI account is connected.
struct CompanionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notes: [Note] = []
    @State private var facts: [UserMemory] = []
    @State private var accountScope = ""
    @State private var editing: SavedMemoryTarget?
    @State private var showMemory = false
    @State private var reloadGeneration = UUID()
    @State private var places: [PlaceVisit] = []
    @State private var reminders: [Reminder] = []
    @State private var tab = "Notes"
    @State private var adding = false
    @State private var notice = ""
    @State private var showNotice = false
    @State private var history = false
    private let storage = StorageService.shared
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Saved things", selection: $tab) {
                        Text("Notes").tag("Notes"); Text("Places").tag("Places"); Text("Reminders").tag("Reminders")
                    }.pickerStyle(.segmented)
                }
                if tab == "Notes" {
                    Section("Your notes") {
                        if notes.isEmpty { Text("Save an idea, a thought, or something you want to keep.").foregroundStyle(.secondary) }
                        ForEach(notes.sorted { $0.updatedAt > $1.updatedAt }) { note in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(note.title).font(.headline)
                                    Spacer()
                                    Button { editing = .note(note) } label: { Image(systemName: "pencil") }
                                        .buttonStyle(.borderless).accessibilityLabel("Edit note \(note.title)")
                                }
                                Text(note.content).textSelection(.enabled)
                                Text(note.updatedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 6)
                        }.onDelete { offsets in
                            let sorted = notes.sorted { $0.updatedAt > $1.updatedAt }
                            offsets.forEach { storage.deleteNote(id: sorted[$0].id, accountScope: accountScope) }; reload()
                        }
                    }
                    factsSection
                    Section { Button { showMemory = true } label: { Label("Personal memory cards", systemImage: "brain") } }
                } else if tab == "Places" {
                    Section("Saved manually") {
                        if places.isEmpty { Text("Save a named place and its address. Max does not track your visits.").foregroundStyle(.secondary) }
                        ForEach(places.reversed()) { place in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(place.destination).font(.headline)
                                if let address = place.note { Text(address).foregroundStyle(.secondary) }
                                Text(place.visitedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Section("Upcoming") {
                        if reminders.isEmpty { Text("Add a time, arrival, or context reminder.").foregroundStyle(.secondary) }
                        ForEach(reminders) { reminder in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(reminder.title).font(.headline)
                                if reminder.triggerKind == "context", let context = reminder.contextName {
                                    Button("Check \(context) now") {
                                        guard storage.accountScope == accountScope else { reload(); return }
                                        let matching = reminders.filter { $0.triggerKind == "context" && $0.contextName?.caseInsensitiveCompare(context) == .orderedSame }
                                        notice = matching.map(\.title).joined(separator: "\n")
                                        matching.forEach { storage.deleteReminder(id: $0.id) }
                                        reload(); showNotice = true
                                    }
                                } else { Text(reminder.triggerSummary(place: places.first { $0.id == reminder.placeID })).foregroundStyle(.secondary) }
                            }.padding(.vertical, 6)
                        }.onDelete { offsets in
                            guard storage.accountScope == accountScope else { reload(); return }
                            offsets.forEach { index in
                                let id = reminders[index].id
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
                                storage.deleteReminder(id: id)
                            }; reload()
                        }
                    }
                }
                Section {
                    Button { history = true } label: { Label("Conversation timeline", systemImage: "clock") }
                    if tab == "Places" {
                        Link("Weather data attribution", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                    }
                }
            }
            .tint(Color(hex: "#315E73"))
            .navigationTitle("Your day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add \(tab.lowercased())") }
            }
            .onAppear { if accountScope.isEmpty { accountScope = storage.accountScope }; reload() }
            .sheet(isPresented: $adding) { CompanionAddSheet(section: tab, places: places, accountScope: accountScope) { reload() } }
            .sheet(item: $editing) { SavedMemoryEditor(target: $0, accountScope: accountScope, onSave: reload) }
            .sheet(isPresented: $showMemory) { MemoryView() }
            .sheet(isPresented: $history) { ConversationHistoryView(onNewChat: { history = false }) }
            .alert("Your reminders", isPresented: $showNotice) { Button("Done", role: .cancel) {} } message: { Text(notice) }
        }
    }
    private var factsSection: some View {
        Section {
            if facts.isEmpty { Text("Ask Max to remember a detail, and it appears here.").foregroundStyle(.secondary) }
            ForEach(facts, id: \.key) { fact in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(fact.key).font(.headline)
                        Spacer()
                        Button { editing = .fact(fact) } label: { Image(systemName: "pencil") }
                            .buttonStyle(.borderless).accessibilityLabel("Edit saved detail \(fact.key)")
                    }
                    Text(fact.value).textSelection(.enabled)
                }.padding(.vertical, 6)
            }
        } header: { Text("Saved details") } footer: { Text("Edits apply to future messages. Conversation history is managed separately.") }
    }
    private func reload() {
        guard storage.accountScope == accountScope else { notes = []; facts = []; places = []; reminders = []; return }
        notes = storage.loadNotes(); places = storage.loadPlaceVisits(); facts = storage.recallFacts().sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        let scope = storage.accountScope
        let generation = UUID(); reloadGeneration = generation
        Task { @MainActor in
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            guard storage.accountScope == scope, reloadGeneration == generation else { return }
            let ids = Set(pending.map(\.identifier))
            reminders = storage.loadReminders().filter {
                $0.triggerKind == "context" || ($0.fireDate > Date() && ids.contains($0.id))
            }.sorted { $0.fireDate < $1.fireDate }
        }
    }
}

private struct CompanionAddSheet: View {
    let section: String
    let places: [PlaceVisit]
    let accountScope: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var kind = "time"
    @State private var fireAt = Date().addingTimeInterval(3600)
    @State private var placeName = ""
    @State private var context = ""
    @State private var saving = false
    @State private var error: String?
    @State private var savedReminder: Reminder?
    var body: some View {
        if let savedReminder {
            ReminderConfirmationView(reminder: savedReminder, places: places, onDone: { dismiss() })
        } else {
            NavigationStack {
                Form { creationFields }
                    .navigationTitle("Add \(section == "Places" ? "place" : section == "Notes" ? "note" : "reminder")")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(saving ? "Saving…" : "Save") { save() }
                                .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
            }
        }
    }
    @ViewBuilder
    private var creationFields: some View {
        TextField(section == "Places" ? "Place name" : "Title", text: $title)
        if section == "Notes" { TextEditor(text: $details).frame(minHeight: 130).accessibilityLabel("Note contents") }
        else if section == "Places" {
            TextField("Street, city, country", text: $details)
            Text("Save a full address for weather and arrival reminders. This does not record a visit.").font(.caption).foregroundStyle(.secondary)
        } else {
            Picker("Remind me", selection: $kind) {
                Text("At a time").tag("time"); Text("When I arrive").tag("location"); Text("In a context").tag("context")
            }
            if kind == "time" { DatePicker("When", selection: $fireAt, in: Date()...) }
            else if kind == "location" {
                Picker("Saved place", selection: $placeName) {
                    Text("Choose a place").tag("")
                    ForEach(places.filter { $0.latitude != nil }) { Text($0.destination).tag($0.destination) }
                }
                Text("iOS delivers this when it detects arrival. Save a place first, and allow location and notifications.").font(.caption).foregroundStyle(.secondary)
            } else {
                TextField("Context, e.g. work or study", text: $context)
                Text("Shown when you explicitly check this context in Max. It does not monitor your activity.").font(.caption).foregroundStyle(.secondary)
            }
        }
        if let error { Text(error).foregroundStyle(.red) }
    }
    private func save() {
        saving = true; error = nil
        let scope = accountScope
        Task { @MainActor in
            guard StorageService.shared.accountScope == scope else { error = "Your account changed. Reopen Your day and try again."; saving = false; return }
            if section == "Notes" {
                guard !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "Write something to save."; saving = false; return }
                StorageService.shared.saveNote(title: title, content: details)
                onSave(); dismiss(); return
            }
            let name: String
            let input: [String: Any]
            if section == "Places" { name = "save_place"; input = ["name": title, "address": details] }
            else if kind == "location" { name = "schedule_location_reminder"; input = ["title": title, "placeName": placeName] }
            else if kind == "context" { name = "schedule_context_reminder"; input = ["title": title, "context": context] }
            else { name = "schedule_reminder"; input = ["title": title, "fireAt": ISO8601DateFormatter().string(from: fireAt)] }
            let result = await ToolsService.shared.execute(name: name, input: input, accountScope: scope)
            guard StorageService.shared.accountScope == scope else { saving = false; return }
            if let data = result.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["success"] as? Bool == true {
                onSave()
                if section == "Reminders", let id = json["id"] as? String,
                   let reminder = StorageService.shared.loadReminders().first(where: { $0.id == id }) { savedReminder = reminder }
                else { dismiss() }
            } else {
                let data = result.data(using: .utf8) ?? Data()
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                error = json?["error"] as? String ?? "Couldn't save. Please try again."
            }
            saving = false
        }
    }
}

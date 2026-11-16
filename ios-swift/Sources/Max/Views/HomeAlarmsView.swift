import SwiftUI

struct HomeAlarmsView: View {
    @ObservedObject var store: ThoughtStore
    let scope: String
    @Environment(\.dismiss) private var dismiss
    @State private var editor: AlarmEditor?

    private struct AlarmEditor: Identifiable {
        var id = UUID()
        var title = "Max alarm"
        var standalone = true
    }

    var body: some View {
        NavigationStack {
            List {
                Button("Set an alarm", systemImage: "alarm") { editor = AlarmEditor() }
                if !store.standaloneAlarms.isEmpty {
                    Section("Scheduled") {
                        ForEach(store.standaloneAlarms, id: \.id) { alarm in
                            Button {
                                editor = AlarmEditor(id: alarm.thoughtID, title: alarm.label ?? "Max alarm")
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alarm.label ?? "Max alarm").foregroundStyle(.primary)
                                    Text(alarm.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                let linked = store.thoughts.filter { store.alert(for: $0.id, kind: .alarm) != nil }
                if !linked.isEmpty {
                    Section("Thought alarms") {
                        ForEach(linked) { thought in
                            Button(thought.title) {
                                editor = AlarmEditor(id: thought.id, title: thought.title, standalone: false)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Alarms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editor) { editor in
                ThoughtAlertView(store: store, thoughtID: editor.id, title: editor.title,
                                 kind: .alarm, scope: scope, standalone: editor.standalone)
            }
        }
    }
}

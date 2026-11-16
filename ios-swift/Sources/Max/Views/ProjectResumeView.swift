import SwiftUI

struct ProjectResumeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var projects: [String] = []
    @State private var selected = ""
    @State private var snapshot: ProjectResume?
    @State private var editing: SavedMemoryTarget?
    let account: String

    var body: some View {
        NavigationStack {
            Form {
                if projects.isEmpty {
                    Text("Save an idea, decision, or next step with a project name to resume it here.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Project", selection: $selected) {
                        ForEach(projects, id: \.self) { Text($0).tag($0) }
                    }
                    if let snapshot {
                        Section("From Memory") {
                            if snapshot.decision == nil { Text("No decision saved yet.").foregroundStyle(.secondary) }
                            if snapshot.openItem == nil { Text("No open item saved yet.").foregroundStyle(.secondary) }
                            ForEach(snapshot.entries) { entry in
                                Button { editing = .fact(entry.fact) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.label).font(.caption).foregroundStyle(.secondary)
                                        Text(entry.fact.value).foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                        if let suggestion = snapshot.suggestion {
                            Section("Suggested next step") { Text(suggestion) }
                        }
                    }
                }
            }
            .navigationTitle("Project Resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear(perform: reload)
            .onChange(of: selected) { _, _ in reload() }
            .sheet(item: $editing) { SavedMemoryEditor(target: $0, accountScope: account, onSave: reload) }
        }
        .tint(Color(hex: "#315E73"))
    }

    private func reload() {
        let store = StorageService.shared
        guard store.accountScope == account else { projects = []; snapshot = nil; dismiss(); return }
        projects = store.resumeProjects
        if !projects.contains(selected) { selected = projects.first ?? "" }
        snapshot = store.projectResume(for: selected)
    }
}

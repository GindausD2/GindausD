import SwiftUI

enum SavedMemoryTarget: Identifiable {
    case note(Note), fact(UserMemory), card(MemoryCard)
    var id: String {
        switch self {
        case .note(let note): return "note:" + note.id
        case .fact(let fact): return "fact:" + fact.key
        case .card(let card): return "card:" + card.id
        }
    }
}

struct SavedMemoryEditor: View {
    let target: SavedMemoryTarget
    let accountScope: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var category: MemoryCategory
    @State private var error: String?
    @State private var confirmForget = false

    init(target: SavedMemoryTarget, accountScope: String, onSave: @escaping () -> Void) {
        self.target = target; self.accountScope = accountScope; self.onSave = onSave
        switch target {
        case .note(let note):
            _title = State(initialValue: note.title); _content = State(initialValue: note.content); _category = State(initialValue: .other)
        case .fact(let fact):
            _title = State(initialValue: fact.key); _content = State(initialValue: fact.value); _category = State(initialValue: .other)
        case .card(let card):
            _title = State(initialValue: "Memory"); _content = State(initialValue: card.content); _category = State(initialValue: card.category)
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Saved detail") {
                    if case .note = target { TextField("Title", text: $title) }
                    else if case .fact = target { Text(title).font(.headline) }
                    else {
                        Picker("Category", selection: $category) {
                            ForEach(MemoryCategory.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    TextEditor(text: $content).frame(minHeight: 140).accessibilityLabel("Saved memory contents")
                }
                Section {
                    Button("Forget this saved item", role: .destructive) { confirmForget = true }
                } footer: {
                    Text("Changes apply to future messages. Previous conversation history is managed separately.")
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .tint(Color(hex: "#315E73"))
            .navigationTitle("Edit saved memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Forget this saved item?", isPresented: $confirmForget) {
                Button("Cancel", role: .cancel) {}
                Button("Forget", role: .destructive) { forget() }
            } message: { Text("This removes the saved item. Earlier conversations remain in your timeline.") }
        }
    }
    private func save() {
        let storage = StorageService.shared
        let saved: Bool
        switch target {
        case .note(let note): saved = storage.updateNote(id: note.id, title: title, content: content, accountScope: accountScope)
        case .fact(let fact): saved = storage.updateFact(key: fact.key, value: content, accountScope: accountScope)
        case .card(let card): saved = storage.updateMemoryCard(id: card.id, content: content, category: category, accountScope: accountScope)
        }
        finish(saved)
    }
    private func forget() {
        let storage = StorageService.shared
        let forgotten: Bool
        switch target {
        case .note(let note): forgotten = storage.deleteNote(id: note.id, accountScope: accountScope)
        case .fact(let fact): forgotten = storage.forgetFact(key: fact.key, accountScope: accountScope)
        case .card(let card): forgotten = storage.deleteMemoryCard(id: card.id, accountScope: accountScope)
        }
        finish(forgotten)
    }
    private func finish(_ success: Bool) {
        if success { onSave(); dismiss() }
        else { error = "This saved item is no longer available in this account. Reopen it and try again." }
    }
}

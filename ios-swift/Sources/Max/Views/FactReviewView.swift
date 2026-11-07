import SwiftUI

struct FactReviewView: View {
    let proposal: FactProposal
    let onFinish: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var value: String

    init(proposal: FactProposal, onFinish: @escaping (String?) -> Void) {
        self.proposal = proposal
        self.onFinish = onFinish
        _value = State(initialValue: proposal.value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Where it belongs") {
                    LabeledContent("Scope", value: proposal.project ?? "Personal")
                    LabeledContent("Fact", value: proposal.key)
                }
                if let previous = proposal.previous {
                    Section("Current value") { Text(previous.value) }
                }
                Section("Exact value to save") {
                    TextEditor(text: $value).frame(minHeight: 110).accessibilityLabel("Value to remember")
                }
            }
            .navigationTitle(proposal.previous == nil ? "Review memory" : "Review correction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Don’t save") { onFinish(nil); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onFinish(value); dismiss() }
                        .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || value.count > 2000)
                }
            }
        }
        .tint(Color(hex: "#315E73"))
    }
}

struct AddFactView: View {
    let account: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var project = ""
    @State private var value = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Where it belongs") {
                    TextField("Fact name", text: $key)
                    TextField("Project name (blank for Personal)", text: $project)
                }
                Section("Exact value to save") {
                    TextEditor(text: $value).frame(minHeight: 110).accessibilityLabel("Value to remember")
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Save a fact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(MemoryIdentity.normalize(key).isEmpty || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(Color(hex: "#315E73"))
    }

    private func save() {
        let storage = StorageService.shared
        guard storage.accountScope == account else { error = "Your account changed."; return }
        switch storage.resolveFact(key: key, value: value, project: project, userText: nil) {
        case .clarify(let question):
            error = question
        case .review(let proposal):
            guard proposal.previous == nil else { error = "That fact already exists. Open it in Memory to edit it."; return }
            guard storage.saveApprovedFact(proposal, value: value, source: "Saved in Memory") != nil else {
                error = "The fact wasn’t saved. Check that saved memory is on and try again."
                return
            }
            onSave()
            dismiss()
        }
    }
}

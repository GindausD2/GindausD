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
    @State private var value: String
    @State private var kind: ProjectMemoryKind = .idea
    @State private var error: String?
    @State private var saved = false
    let isVoiceCapture: Bool
    let captureNotice: String?

    init(account: String, capturedText: String? = nil, captureNotice: String? = nil, onSave: @escaping () -> Void) {
        self.account = account
        self.onSave = onSave
        isVoiceCapture = capturedText != nil
        self.captureNotice = captureNotice
        _value = State(initialValue: capturedText ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Where it belongs") {
                    if isVoiceCapture {
                        Picker("Type", selection: $kind) {
                            ForEach(ProjectMemoryKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                    TextField(isVoiceCapture ? "Title" : "Fact name", text: $key)
                    TextField("Project name (blank for Personal)", text: $project)
                    if isVoiceCapture {
                        let projects = StorageService.shared.accountScope == account ? StorageService.shared.resumeProjects : []
                        if !projects.isEmpty {
                            Menu("Choose a saved project") {
                                Button("Personal") { project = "" }
                                ForEach(projects, id: \.self) { name in
                                    Button(name) { project = name }
                                }
                            }
                        }
                    }
                }
                Section("Exact value to save") {
                    TextEditor(text: $value).frame(minHeight: 110).accessibilityLabel("Value to remember")
                }
                if let captureNotice { Text(captureNotice).font(.footnote).foregroundStyle(.secondary) }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .alert("Thought saved", isPresented: $saved) {
                Button("Done") { dismiss() }
            } message: {
                Text("You can find it in Your Space → Memory.")
            }
            .navigationTitle(isVoiceCapture ? "Review your thought" : "Save a fact")
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
        let title = isVoiceCapture ? kind.rawValue + ": " + key : key
        switch storage.resolveFact(key: title, value: value, project: project, userText: nil) {
        case .clarify(let question):
            error = question
        case .review(let proposal):
            guard proposal.previous == nil else { error = "That fact already exists. Open it in Memory to edit it."; return }
            guard storage.saveApprovedFact(proposal, value: value, source: isVoiceCapture ? "Voice capture · reviewed by you" : "Saved in Memory") != nil else {
                error = "The fact wasn’t saved. Check that saved memory is on and try again."
                return
            }
            onSave()
            if isVoiceCapture { saved = true }
            else { dismiss() }
        }
    }
}

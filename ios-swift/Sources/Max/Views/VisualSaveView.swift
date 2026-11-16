import SwiftUI

enum VisualSaveKind: String, CaseIterable, Identifiable {
    case note, reminder, memory
    var id: Self { self }
    var title: String {
        switch self {
        case .note: "Save as note"
        case .reminder: "Set a reminder"
        case .memory: "Save to memory"
        }
    }
}

struct VisualSaveView: View {
    let kind: VisualSaveKind
    let account: String
    let sourceText: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text: String
    @State private var category: MemoryCategory = .other
    @State private var date = Date.now.addingTimeInterval(3600)
    @State private var error: String?
    @State private var work: Task<Void, Never>?

    init(kind: VisualSaveKind, text: String, account: String, onSave: @escaping (String) -> Void) {
        self.kind = kind
        self.account = account
        sourceText = text
        self.onSave = onSave
        _text = State(initialValue: kind == .memory ? "" : text)
    }

    var body: some View {
        NavigationStack {
            Form {
                if kind != .memory {
                    TextField("Title", text: $title)
                }
                if kind == .memory {
                    Picker("Category", selection: $category) {
                        ForEach(MemoryCategory.allCases, id: \.self) { category in
                            Label(category.label, systemImage: category.iconName).tag(category)
                        }
                    }
                }
                Section(kind == .memory ? "What should Max remember?" : "Details") {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Details")
                    if kind == .memory && !sourceText.isEmpty && text.isEmpty {
                        Button("Use result text") { text = sourceText }
                    }
                }
                if kind == .reminder {
                    DatePicker("Remind me", selection: $date, in: Date.now...)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .disabled(work != nil)
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(kind == .reminder ? "Schedule" : "Save", action: save)
                        .disabled(work != nil || (kind == .memory ? text.trimmedForSave.isEmpty : title.trimmedForSave.isEmpty))
                }
            }
        }
        .onDisappear { work?.cancel() }
    }

    private func save() {
        guard work == nil, StorageService.shared.accountScope == account else {
            error = "Your account changed. Reopen the camera and try again."
            return
        }
        let content = text.trimmedForSave
        let name = title.trimmedForSave
        if kind == .memory {
            guard !content.isEmpty, StorageService.shared.saveMemoryCard(
                MemoryCard(category: category, content: content), accountScope: account
            ) else {
                error = "Max couldn’t save this memory."
                return
            }
            finish("Saved to Memory")
            return
        }

        guard !name.isEmpty else { return }
        let input: [String: Any]
        let action: String
        if kind == .note {
            action = "save_note"
            input = ["title": name, "content": content]
        } else {
            action = "schedule_reminder"
            input = ["title": name, "body": content, "fireAt": ISO8601DateFormatter().string(from: date)]
        }
        error = nil
        work = Task { @MainActor in
            defer { work = nil }
            let response = await ToolsService.shared.execute(name: action, input: input, accountScope: account)
            guard !Task.isCancelled, StorageService.shared.accountScope == account else { return }
            let result = (try? JSONSerialization.jsonObject(with: Data(response.utf8))) as? [String: Any]
            if result?["success"] as? Bool == true {
                finish(kind == .note ? "Note saved" : "Reminder scheduled")
            } else {
                error = result?["error"] as? String ?? "Max couldn’t save this item."
            }
        }
    }

    private func finish(_ message: String) {
        onSave(message)
        dismiss()
    }
}

private extension String {
    var trimmedForSave: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

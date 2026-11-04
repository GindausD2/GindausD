import SwiftUI

struct VocabularyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthService.shared
    @State private var scope = ""
    @State private var words: [String] = []
    @State private var newWord = ""
    @State private var error: String?
    private let storage = StorageService.shared
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(words, id: \.self) { Text($0) }
                        .onDelete { offsets in words.remove(atOffsets: offsets); save() }
                    HStack {
                        TextField("Name or phrase", text: $newWord).textInputAutocapitalization(.never).autocorrectionDisabled().onSubmit(add)
                        Button("Add", action: add).disabled(words.count >= 25 || newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: { Text("Personal vocabulary · \(words.count)/25") }
                footer: { Text("Add names and terms you actually say, such as Gindaus or TeemFlow. These hints go to the transcription provider with future recordings. They guide recognition; they do not replace words or guarantee a spelling.") }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }.navigationTitle("Voice vocabulary")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onAppear { if scope.isEmpty { scope = storage.accountScope }; reload() }
                .onChange(of: auth.currentUser) { _, _ in reload() }
        }.tint(Color(hex: "#315E73"))
    }
    private func reload() { words = storage.accountScope == scope ? storage.loadVocabulary() : [] }
    private func add() {
        let word = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = words + [word]
        if storage.saveVocabulary(updated, accountScope: scope) { words = updated; newWord = ""; error = nil }
        else { error = "Use a unique name or phrase of 1–64 characters, without line breaks or angle brackets. Up to 25 entries per account." }
    }
    private func save() {
        if storage.saveVocabulary(words, accountScope: scope) { error = nil }
        else { error = "Your account changed. Reopen vocabulary."; reload() }
    }
}

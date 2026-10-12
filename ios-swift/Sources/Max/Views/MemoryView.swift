import SwiftUI

struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: MemoryCategory = .personal
    @State private var cards: [MemoryCard] = []
    @State private var accountScope = ""
    @State private var adding = false
    @State private var editing: SavedMemoryTarget?
    private let storage = StorageService.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(MemoryCategory.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                } footer: { Text("Keep the details you want Max to remember. Edit or forget them whenever you need.") }
                Section(selectedCategory.label) {
                    if filteredCards.isEmpty { Text(selectedCategory.emptySubtitle).foregroundStyle(.secondary) }
                    ForEach(filteredCards) { card in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(card.content).textSelection(.enabled)
                            HStack {
                                Text(card.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button { editing = .card(card) } label: { Label("Edit", systemImage: "pencil") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Edit memory: \(String(card.content.prefix(70)))")
                            }
                        }.padding(.vertical, 6)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LinearGradient(colors: [Color(hex: "#F9F7F2"), Color(hex: "#DCE4DA")], startPoint: .top, endPoint: .bottom))
            .tint(Color(hex: "#315E73"))
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add saved memory") }
            }
            .onAppear { if accountScope.isEmpty { accountScope = storage.accountScope }; reload() }
            .sheet(isPresented: $adding) { AddMemorySheet(category: selectedCategory, accountScope: accountScope, onSave: reload) }
            .sheet(item: $editing) { SavedMemoryEditor(target: $0, accountScope: accountScope, onSave: reload) }
        }
    }
    private var filteredCards: [MemoryCard] {
        cards.filter { $0.category == selectedCategory }.sorted { $0.createdAt > $1.createdAt }
    }
    private func reload() {
        guard storage.accountScope == accountScope else { cards = []; return }
        cards = storage.loadMemoryCards()
    }
}

private struct AddMemorySheet: View {
    let category: MemoryCategory
    let accountScope: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("What would you like Max to remember?") {
                    TextEditor(text: $text).frame(minHeight: 150).accessibilityLabel("New memory contents")
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .tint(Color(hex: "#315E73"))
            .navigationTitle("Add \(category.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let card = MemoryCard(category: category, content: text.trimmingCharacters(in: .whitespacesAndNewlines))
                        if StorageService.shared.saveMemoryCard(card, accountScope: accountScope) { onSave(); dismiss() }
                        else { error = "Your account changed. Reopen Memory to save this detail." }
                    }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview { MemoryView() }

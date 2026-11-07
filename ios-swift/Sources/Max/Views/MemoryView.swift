import SwiftUI
import UIKit

struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = AuthService.shared
    let initialFactID: String?
    @State private var query = ""
    @State private var facts: [UserMemory] = []
    @State private var selectedCategory: MemoryCategory = .personal
    @State private var cards: [MemoryCard] = []
    @State private var accountScope = ""
    @State private var adding = false
    @State private var addingFact = false
    @State private var chooseAdd = false
    @State private var editing: SavedMemoryTarget?
    @State private var memoryEnabled = true
    @State private var showLifeMemory = false
    private let storage = StorageService.shared

    init(initialFactID: String? = nil) { self.initialFactID = initialFactID }

    var body: some View {
        ZStack {
            CompanionCanvas()
            VStack(spacing: 0) {
                CompanionSheetHeader(title: "Memory", onClose: { dismiss() }, onAdd: { chooseAdd = true })
                Button { showLifeMemory = true } label: { Label("Life Memory timeline", systemImage: "calendar.badge.clock") }.padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Use saved memory", isOn: Binding(get: { memoryEnabled }, set: { enabled in
                        guard storage.accountScope == accountScope else { return }
                        memoryEnabled = enabled; storage.setMemoryEnabled(enabled, accountScope: accountScope)
                    }))
                    Text(memoryEnabled ? "Edit or forget saved details anytime." : "Memory is paused. Max won't use saved details or save new facts. Existing memories stay here; chat history is separate.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, 20).padding(.vertical, 12)
                TextField("Search saved memory", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Search saved memory")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(MemoryCategory.allCases, id: \.self) { category in
                            Button { selectedCategory = category } label: {
                                Label(category.label, systemImage: category.iconName)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 15).padding(.vertical, 11)
                                    .frame(minHeight: 44)
                                    .foregroundStyle(selectedCategory == category ? Color(UIColor.systemBackground) : Color.primary)
                                    .background(selectedCategory == category ? Color.primary : Color.clear, in: Capsule())
                                    .if(selectedCategory != category) { $0.glassCard(cornerRadius: 24, interactive: true) }
                            }.buttonStyle(.plain)
                                .accessibilityValue(selectedCategory == category ? "Selected" : "")
                        }
                    }.padding(.horizontal, 20)
                }.padding(.vertical, 8)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if !filteredFacts.isEmpty {
                            Text("Current facts").font(.headline).accessibilityAddTraits(.isHeader)
                            ForEach(filteredFacts) { fact in
                                Button { editing = .fact(fact) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(fact.key).font(.headline)
                                        Text(fact.value)
                                        Text(fact.scopeLabel).font(.caption.weight(.semibold))
                                        Text(fact.updatedAt, style: .date).font(.caption)
                                        if let source = fact.source { Text(source).font(.caption) }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16).glassCard(cornerRadius: 22, interactive: true)
                                }.buttonStyle(.plain)
                            }
                        }
                        Text("Source cards").font(.headline).accessibilityAddTraits(.isHeader)
                        if filteredCards.isEmpty {
                            Text(query.isEmpty ? "No cards in this category." : "No matching cards.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(filteredCards) { card in
                            Button { editing = .card(card) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(card.content)
                                    Text(card.updatedAt ?? card.createdAt, style: .date).font(.caption)
                                    Text("Personal · Saved card").font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16).glassCard(cornerRadius: 22, interactive: true)
                            }.buttonStyle(.plain)
                        }
                    }.padding(20)
                }
            }
        }
        .tint(Color(hex: "#315E73"))
        .presentationCornerRadius(34).presentationDragIndicator(.hidden)
        .onAppear {
            if accountScope.isEmpty {
                accountScope = storage.accountScope
                reload()
                if let initialFactID, let fact = facts.first(where: { $0.id == initialFactID }) { editing = .fact(fact) }
            } else { reload() }
        }
        .onChange(of: authService.currentUser) { _, _ in reload() }
        .confirmationDialog("Add to Memory", isPresented: $chooseAdd, titleVisibility: .visible) {
            Button("Save a fact") { addingFact = true }
            Button("Save a source card") { adding = true }
        }
        .sheet(isPresented: $addingFact) { AddFactView(account: accountScope, onSave: reload) }
        .sheet(isPresented: $adding) { AddMemorySheet(category: selectedCategory, accountScope: accountScope, onSave: reload) }
        .sheet(isPresented: $showLifeMemory) { LifeMemoryView() }
        .sheet(item: $editing) { SavedMemoryEditor(target: $0, accountScope: accountScope, onSave: reload) }
    }
    private var filteredFacts: [UserMemory] {
        facts.filter {
            query.isEmpty || [$0.key, $0.value, $0.scopeLabel, $0.source ?? ""].contains { $0.localizedCaseInsensitiveContains(query) }
        }.sorted { $0.updatedAt > $1.updatedAt }
    }
    private var filteredCards: [MemoryCard] {
        cards.filter {
            query.isEmpty ? $0.category == selectedCategory : $0.content.localizedCaseInsensitiveContains(query)
        }.sorted { ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) }
    }
    private func reload() {
        guard storage.accountScope == accountScope else { cards = []; facts = []; dismiss(); return }
        facts = storage.recallFacts()
        cards = storage.loadMemoryCards()
        memoryEnabled = storage.usesSavedMemory
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


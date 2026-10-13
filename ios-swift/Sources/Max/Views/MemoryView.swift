import SwiftUI
import UIKit

struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = AuthService.shared
    @State private var selectedCategory: MemoryCategory = .personal
    @State private var cards: [MemoryCard] = []
    @State private var accountScope = ""
    @State private var adding = false
    @State private var editing: SavedMemoryTarget?
    private let storage = StorageService.shared

    var body: some View {
        ZStack {
            CompanionCanvas()
            VStack(spacing: 0) {
                CompanionSheetHeader(title: "Memory", onClose: { dismiss() }, onAdd: { adding = true })
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
                GeometryReader { geometry in
                    ScrollView {
                        if filteredCards.isEmpty {
                            VStack(spacing: 18) {
                                Image(systemName: selectedCategory.iconName)
                                    .font(.system(size: 34, weight: .regular)).foregroundStyle(.secondary)
                                Text("Nothing saved here yet.").font(.title3.weight(.semibold))
                                Text(selectedCategory.emptySubtitle)
                                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                Button { adding = true } label: {
                                    Label("Add \(selectedCategory.label)", systemImage: "plus")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 24).padding(.vertical, 14)
                                        .foregroundStyle(Color(UIColor.systemBackground))
                                        .background(Color.primary, in: Capsule())
                                }.buttonStyle(.plain).padding(.top, 6)
                            }
                            .padding(.horizontal, 30).padding(.vertical, 30)
                            .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                Text("Keep what matters. Edit or forget it anytime.")
                                    .font(.caption).foregroundStyle(.secondary).padding(.bottom, 4)
                                ForEach(filteredCards) { card in
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text(card.content).font(.body).textSelection(.enabled)
                                        HStack {
                                            Text(card.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                            Spacer()
                                            Button { editing = .card(card) } label: { Label("Edit", systemImage: "pencil") }
                                                .font(.caption.weight(.semibold))
                                                .accessibilityLabel("Edit memory: \(String(card.content.prefix(70)))")
                                        }
                                    }
                                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                    .glassCard(cornerRadius: 26)
                                }
                            }.padding(20)
                        }
                    }
                }
            }
        }
        .tint(Color(hex: "#315E73"))
        .presentationCornerRadius(34).presentationDragIndicator(.hidden)
        .onAppear { if accountScope.isEmpty { accountScope = storage.accountScope }; reload() }
        .onChange(of: authService.currentUser) { _, _ in reload() }
        .sheet(isPresented: $adding) { AddMemorySheet(category: selectedCategory, accountScope: accountScope, onSave: reload) }
        .sheet(item: $editing) { SavedMemoryEditor(target: $0, accountScope: accountScope, onSave: reload) }
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

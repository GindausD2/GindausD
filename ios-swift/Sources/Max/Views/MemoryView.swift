import SwiftUI

// MARK: - MemoryView

struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: MemoryCategory = .personal
    @State private var cards: [MemoryCard] = []
    @State private var showAddSheet: Bool = false

    private let storage = StorageService.shared

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                memoryHeader
                categoryTabs

                if filteredCards.isEmpty {
                    emptyState
                } else {
                    cardList
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMemorySheet(category: selectedCategory) { card in
                cards.append(card)
                storage.saveMemoryCards(cards)
            }
        }
        .onAppear { cards = storage.loadMemoryCards() }
    }

    // MARK: - Subviews

    private var memoryHeader: some View {
        ZStack {
            VStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                Spacer()
            }

            HStack {
                Button { dismiss() } label: {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.tertiarySystemFill))
                            .frame(width: 30, height: 30)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 16).padding(.top, 4)

                Spacer()

                Text("Memory")
                    .font(.headline.weight(.semibold))
                    .padding(.top, 4)

                Spacer()

                Button { showAddSheet = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.tertiarySystemFill))
                            .frame(width: 30, height: 30)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.trailing, 16).padding(.top, 4)
            }
        }
        .frame(height: 50)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MemoryCategory.allCases, id: \.self) { cat in
                    let selected = selectedCategory == cat
                    Button { selectedCategory = cat } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.iconName)
                                .font(.system(size: 13, weight: .medium))
                            Text(cat.label)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selected ? Color.black : Color(UIColor.systemBackground))
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(UIColor.separator),
                                              lineWidth: selected ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.18), value: selectedCategory)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var filteredCards: [MemoryCard] {
        cards.filter { $0.category == selectedCategory }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: selectedCategory.iconName)
                .font(.system(size: 52))
                .foregroundStyle(Color(UIColor.systemGray3))

            Text(selectedCategory.emptyTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(selectedCategory.emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button { showAddSheet = true } label: {
                Label("Add \(selectedCategory.label)", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private var cardList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(filteredCards) { card in
                    HStack(alignment: .top, spacing: 12) {
                        Text(card.content)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            withAnimation {
                                cards.removeAll { $0.id == card.id }
                                storage.saveMemoryCards(cards)
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(7)
                                .background(Color(UIColor.tertiarySystemFill), in: Circle())
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Add Memory Sheet

private struct AddMemorySheet: View {
    let category: MemoryCategory
    var onSave: (MemoryCard) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("What would you like Max to remember?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(minHeight: 120)
                    .padding(.horizontal, 16)

                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Add \(category.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !trimmed.isEmpty else { return }
                        onSave(MemoryCard(category: category, content: trimmed))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmed.isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}

// MARK: - Preview

#Preview {
    MemoryView()
}

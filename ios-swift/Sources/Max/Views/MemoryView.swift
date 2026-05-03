import SwiftUI

// MARK: - MemoryView  (iOS 26 Liquid Glass)

struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: MemoryCategory = .personal
    @State private var cards: [MemoryCard] = []
    @State private var showAddSheet: Bool = false

    private let storage = StorageService.shared
    private let violet = Color(hex: "#7C3AED")

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // ── Liquid-glass background gradient ──────────────────────────────
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.98, green: 0.97, blue: 1.00), location: 0.00),
                    .init(color: Color(red: 0.95, green: 0.93, blue: 1.00), location: 0.50),
                    .init(color: Color(red: 0.91, green: 0.87, blue: 1.00), location: 1.00),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ambient violet blob (top-right)
            Circle()
                .fill(violet.opacity(0.07))
                .frame(width: 260)
                .blur(radius: 60)
                .offset(x: 100, y: -40)
                .ignoresSafeArea()

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

    // MARK: - Glass Header

    private var memoryHeader: some View {
        ZStack {
            // Glass bar layers
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(Color.white.opacity(0.55))

            // Specular top streak
            VStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.90), Color.white.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 2)
                Spacer()
            }

            // Bottom hairline
            VStack {
                Spacer()
                LinearGradient(
                    colors: [violet.opacity(0.18), violet.opacity(0.06)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)
            }

            // Handle
            VStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.28))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                Spacer()
            }

            // Buttons + title
            HStack {
                glassCircleButton(icon: "xmark", iconSize: 12) { dismiss() }
                    .padding(.leading, 16).padding(.top, 4)

                Spacer()

                Text("Memory")
                    .font(.headline.weight(.semibold))
                    .padding(.top, 4)

                Spacer()

                glassCircleButton(icon: "plus", iconSize: 14) { showAddSheet = true }
                    .padding(.trailing, 16).padding(.top, 4)
            }
        }
        .frame(height: 50)
        .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
        .shadow(color: violet.opacity(0.05), radius: 20, y: 8)
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MemoryCategory.allCases, id: \.self) { cat in
                    categoryPill(cat)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private func categoryPill(_ cat: MemoryCategory) -> some View {
        let selected = selectedCategory == cat
        Button { selectedCategory = cat } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.iconName)
                    .font(.system(size: 13, weight: .medium))
                Text(cat.label)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? .white : .primary)
            .background {
                if selected {
                    // Selected: violet glass capsule
                    Capsule()
                        .fill(violet)
                        .overlay {
                            // specular sheen
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color.white.opacity(0.30), .clear],
                                    startPoint: .top, endPoint: .center
                                ))
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(LinearGradient(
                                    colors: [Color.white.opacity(0.55), violet.opacity(0.25)],
                                    startPoint: .top, endPoint: .bottom
                                ), lineWidth: 1)
                        }
                        .shadow(color: violet.opacity(0.45), radius: 10, y: 5)
                        .shadow(color: violet.opacity(0.20), radius: 20, y: 10)
                } else {
                    // Unselected: clear glass capsule
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule().fill(Color.white.opacity(0.50))
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(LinearGradient(
                                    colors: [Color.white.opacity(0.75), Color.black.opacity(0.07)],
                                    startPoint: .top, endPoint: .bottom
                                ), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.07), radius: 5, y: 3)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.26, bounce: 0.3), value: selectedCategory)
    }

    // MARK: - Helpers

    private var filteredCards: [MemoryCard] {
        cards.filter { $0.category == selectedCategory }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            // Glass icon medallion
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 92, height: 92)
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 92, height: 92)
                // Specular streak on medallion
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.70), .clear],
                        startPoint: .top, endPoint: .center
                    ))
                    .frame(width: 92, height: 92)
                Circle()
                    .strokeBorder(LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.black.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom
                    ), lineWidth: 1)
                    .frame(width: 92, height: 92)

                Image(systemName: selectedCategory.iconName)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(violet.opacity(0.75))
            }
            .shadow(color: .black.opacity(0.09), radius: 18, y: 8)
            .shadow(color: violet.opacity(0.12), radius: 24, y: 10)

            Text(selectedCategory.emptyTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(selectedCategory.emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Glass CTA button
            Button { showAddSheet = true } label: {
                Label("Add \(selectedCategory.label)", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(violet)
                            .overlay {
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Color.white.opacity(0.28), .clear],
                                        startPoint: .top, endPoint: .center
                                    ))
                            }
                            .overlay {
                                Capsule()
                                    .strokeBorder(LinearGradient(
                                        colors: [Color.white.opacity(0.55), violet.opacity(0.20)],
                                        startPoint: .top, endPoint: .bottom
                                    ), lineWidth: 1)
                            }
                            .shadow(color: violet.opacity(0.48), radius: 14, y: 7)
                            .shadow(color: violet.opacity(0.22), radius: 24, y: 12)
                    }
            }
            .padding(.top, 4)

            Spacer()
        }
    }

    // MARK: - Card List

    private var cardList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(filteredCards) { card in
                    glassCard(card)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func glassCard(_ card: MemoryCard) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(card.content)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(.spring(duration: 0.32)) {
                    cards.removeAll { $0.id == card.id }
                    storage.saveMemoryCards(cards)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(7)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5)
                    }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.62))
                }
                .overlay {
                    // Specular top streak
                    VStack {
                        LinearGradient(
                            colors: [Color.white.opacity(0.85), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 28)
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(LinearGradient(
                            colors: [Color.white.opacity(0.85), Color.black.opacity(0.06)],
                            startPoint: .top, endPoint: .bottom
                        ), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
                .shadow(color: violet.opacity(0.04), radius: 16, y: 8)
        }
    }

    // MARK: - Glass Circle Button

    @ViewBuilder
    private func glassCircleButton(icon: String, iconSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 30, height: 30)
                Circle()
                    .fill(Color.white.opacity(0.52))
                    .frame(width: 30, height: 30)
                // Specular top sheen
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.65), .clear],
                        startPoint: .top, endPoint: .center
                    ))
                    .frame(width: 30, height: 30)
                Circle()
                    .strokeBorder(LinearGradient(
                        colors: [Color.white.opacity(0.80), Color.black.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom
                    ), lineWidth: 1)
                    .frame(width: 30, height: 30)

                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .shadow(color: .black.opacity(0.09), radius: 6, y: 3)
        }
    }
}

// MARK: - Add Memory Sheet  (liquid glass)

private struct AddMemorySheet: View {
    let category: MemoryCategory
    var onSave: (MemoryCard) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private let violet = Color(hex: "#7C3AED")

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.98, green: 0.97, blue: 1.00), location: 0.0),
                        .init(color: Color(red: 0.94, green: 0.91, blue: 1.00), location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

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
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.60))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(LinearGradient(
                                            colors: [Color.white.opacity(0.80), Color.black.opacity(0.07)],
                                            startPoint: .top, endPoint: .bottom
                                        ), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                        }
                        .frame(minHeight: 120)
                        .padding(.horizontal, 16)

                    Spacer()
                }
            }
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

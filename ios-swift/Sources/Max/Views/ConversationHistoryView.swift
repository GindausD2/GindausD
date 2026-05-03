import SwiftUI

// MARK: - ConversationHistoryView

struct ConversationHistoryView: View {
    var onNewChat: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var conversations: [Conversation] = []
    @State private var selected: Conversation? = nil
    @State private var searchText: String = ""

    private let storage = StorageService.shared

    private var filtered: [Conversation] {
        guard !searchText.isEmpty else { return conversations }
        let q = searchText.lowercased()
        return conversations.filter {
            $0.title.lowercased().contains(q) ||
            $0.messages.contains { $0.content.lowercased().contains(q) }
        }
    }

    private var grouped: [(label: String, items: [Conversation])] {
        let cal = Calendar.current
        let now = Date()
        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var week: [Conversation] = []
        var older: [Conversation] = []

        for c in filtered {
            if cal.isDateInToday(c.updatedAt)     { today.append(c) }
            else if cal.isDateInYesterday(c.updatedAt) { yesterday.append(c) }
            else if let d = cal.date(byAdding: .day, value: -7, to: now), c.updatedAt > d {
                week.append(c)
            } else {
                older.append(c)
            }
        }

        var result: [(String, [Conversation])] = []
        if !today.isEmpty     { result.append(("Today", today)) }
        if !yesterday.isEmpty { result.append(("Yesterday", yesterday)) }
        if !week.isEmpty      { result.append(("Previous 7 Days", week)) }
        if !older.isEmpty     { result.append(("Older", older)) }
        return result
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                if conversations.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(grouped, id: \.label) { group in
                            Section(header: Text(group.label).font(.caption.weight(.semibold))) {
                                ForEach(group.items) { conv in
                                    ConversationRow(conversation: conv)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selected = conv }
                                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                                }
                                .onDelete { offsets in
                                    deleteItems(in: group.items, at: offsets)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Search conversations")
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onNewChat?()
                    } label: {
                        Label("New Chat", systemImage: "square.and.pencil")
                    }
                }
            }
        }
        .onAppear { conversations = storage.loadConversations() }
        .sheet(item: $selected) { conv in
            ConversationReplayView(conversation: conv)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.5))
            Text("No conversations yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Your chats with Max will appear here\nafter your first conversation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Delete

    private func deleteItems(in group: [Conversation], at offsets: IndexSet) {
        for idx in offsets {
            storage.deleteConversation(id: group[idx].id)
        }
        conversations = storage.loadConversations()
    }
}

// MARK: - ConversationRow

private struct ConversationRow: View {
    let conversation: Conversation

    private var timeString: String {
        let cal = Calendar.current
        if cal.isDateInToday(conversation.updatedAt) {
            return conversation.updatedAt.formatted(date: .omitted, time: .shortened)
        }
        return conversation.updatedAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(conversation.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !conversation.assistantPreview.isEmpty {
                Text(conversation.assistantPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 4) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 9))
                Text("\(conversation.userMessageCount) \(conversation.userMessageCount == 1 ? "message" : "messages")")
                    .font(.caption2)
            }
            .foregroundStyle(Color(hex: "#7C3AED").opacity(0.7))
        }
        .padding(.vertical, 10)
    }
}

// MARK: - ConversationReplayView

struct ConversationReplayView: View {
    let conversation: Conversation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.00, green: 1.00, blue: 1.00), location: 0.0),
                        .init(color: Color(red: 0.97, green: 0.96, blue: 1.00), location: 0.5),
                        .init(color: Color(red: 0.94, green: 0.91, blue: 1.00), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(conversation.messages) { msg in
                                TranscriptBubble(message: msg, isStreaming: false)
                                    .id(msg.id)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                    .onAppear {
                        if let last = conversation.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle(conversation.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ConversationHistoryView()
}

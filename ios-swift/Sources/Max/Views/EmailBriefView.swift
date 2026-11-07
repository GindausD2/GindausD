import SwiftUI

struct EmailBriefView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var auth: AuthService
    @ObservedObject private var email = EmailMonitorService.shared

    @State private var sender = ""
    @State private var results: [BriefEmail] = []
    @State private var selected: BriefEmail?
    @State private var brief: EmailBrief?
    @State private var error: String?
    @State private var searched = false
    @State private var needsReconnect = false
    @State private var busy = false
    @State private var work: Task<Void, Never>?
    @FocusState private var senderFocused: Bool

    private let accent = Color(hex: "#315E73")

    var body: some View {
        NavigationStack {
            ZStack {
                CompanionCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Catch up before you answer.")
                            .font(.title2.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text("Find an email by sender, then tap it for a private brief.")
                            .foregroundStyle(.secondary)

                        if auth.currentUser == nil || auth.currentUser?.isDemo == true {
                            Text("Sign in to your Max account to use Email Brief.")
                        } else if email.clientID.isEmpty {
                            Text("Gmail connection is unavailable in this build.")
                        } else if !email.isConnected || needsReconnect {
                            Button(needsReconnect ? "Reconnect Gmail" : "Connect Gmail", action: connect)
                                .buttonStyle(.borderedProminent)
                            Text("Max uses read-only Gmail access. The selected message is processed on this device.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            searchField
                            if let selected, let brief {
                                briefCard(brief, for: selected)
                            }
                            if !results.isEmpty {
                                matches
                            } else if searched && error == nil && !busy {
                                Text("No matching emails. Try the sender’s full email address.")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if busy {
                            ProgressView(selected == nil ? "Working…" : "Reading the selected email…")
                        }
                        if let error {
                            Text(error).font(.footnote).foregroundStyle(.primary)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollDismissesKeyboard(.interactively)
                .privacySensitive()
                .opacity(scenePhase == .active ? 1 : 0)
                .accessibilityHidden(scenePhase != .active)
            }
            .tint(accent)
            .navigationTitle("Email Brief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: auth.currentUser?.storageScope) { _, _ in
            work?.cancel()
            results = []
            selected = nil
            brief = nil
            dismiss()
        }
        .onDisappear { work?.cancel() }
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name or email address", text: $sender)
                .accessibilityLabel("Sender name or email address")
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($senderFocused)
                .onSubmit(search)
            Button("Find emails", systemImage: "magnifyingglass", action: search)
                .buttonStyle(.borderedProminent)
                .disabled(sender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
        .disabled(busy)
    }

    private var matches: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matching emails").font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(results) { match in
                Button {
                    summarize(match)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(match.subject).font(.headline)
                            Text(match.sender).font(.subheadline)
                            if match.receivedAt.timeIntervalSince1970 > 0 {
                                Text(match.receivedAt, format: .dateTime.month().day().year())
                                    .font(.caption)
                            }
                        }
                        Spacer()
                        Image(systemName: "text.alignleft").accessibilityHidden(true)
                    }
                    .foregroundStyle(.primary)
                    .padding(14)
                    .glassCard(cornerRadius: 18, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Summarize this email")
                .disabled(busy)
            }
        }
    }

    private func briefCard(_ value: EmailBrief, for message: BriefEmail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.subject).font(.headline).accessibilityAddTraits(.isHeader)
                Text(message.sender).font(.footnote).foregroundStyle(.secondary)
            }
            briefSection(value.usedExtracts ? "Key lines from the email" : "Summary", value.summary)
            if !value.requestedOpinion.isEmpty {
                briefSection(value.usedExtracts ? "Question in the email" : "What they’re asking", value.requestedOpinion)
            }
            briefSection(value.usedExtracts ? "Conversation starter" : "Suggested response", value.suggestedResponse)
            if value.isPartial {
                Text("This brief covers the opening of a long email.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private func briefSection(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text(detail)
        }
    }

    private func connect() {
        guard !busy else { return }
        begin {
            let connected = await email.connect()
            try Task.checkCancellation()
            if connected {
                needsReconnect = false
            } else {
                error = email.connectError
            }
        }
    }

    private func search() {
        guard !busy else { return }
        senderFocused = false
        let query = sender
        results = []
        selected = nil
        brief = nil
        searched = false
        begin {
            let matches = try await email.searchForBrief(sender: query)
            try Task.checkCancellation()
            results = matches
            searched = true
        }
    }

    private func summarize(_ message: BriefEmail) {
        guard !busy else { return }
        selected = message
        brief = nil
        begin {
            let text = try await email.bodyForBrief(message)
            let result = try await EmailBrief.make(from: text)
            try Task.checkCancellation()
            brief = result
        }
    }

    private func begin(_ operation: @escaping @MainActor () async throws -> Void) {
        error = nil
        busy = true
        work = Task { @MainActor in
            defer { busy = false; work = nil }
            do {
                try await operation()
            } catch is CancellationError {
                return
            } catch let failure as BriefEmail.Failure {
                if case .expired = failure {
                    needsReconnect = true
                    results = []
                    selected = nil
                    brief = nil
                }
                error = failure.localizedDescription
            } catch {
                self.error = "Max couldn’t load this email. Please try again."
            }
        }
    }
}

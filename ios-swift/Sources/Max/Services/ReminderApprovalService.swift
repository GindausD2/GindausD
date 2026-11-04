import Foundation
import Combine
import SwiftUI

struct ReminderProposal: Identifiable {
    let id = UUID()
    let reminder: Reminder
    let detail: String
    let accountScope: String
}

@MainActor
final class ReminderApprovalService: ObservableObject {
    static let shared = ReminderApprovalService()
    @Published private(set) var pending: ReminderProposal?
    private var waiter: CheckedContinuation<Bool, Never>?

    func confirm(_ reminder: Reminder, detail: String, scope: String) async -> Bool {
        guard !Task.isCancelled, StorageService.shared.accountScope == scope, pending == nil else { return false }
        let proposal = ReminderProposal(reminder: reminder, detail: detail, accountScope: scope)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(returning: false); return }
                waiter = continuation; pending = proposal
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.resolve(id: proposal.id, approved: false) }
        }
    }

    func resolve(id: UUID, approved: Bool) {
        guard let proposal = pending, proposal.id == id else { return }
        let allowed = approved && proposal.accountScope == StorageService.shared.accountScope
        pending = nil
        let continuation = waiter; waiter = nil
        continuation?.resume(returning: allowed)
    }

    func cancel() { if let id = pending?.id { resolve(id: id, approved: false) } }
}

struct ReminderApprovalView: View {
    let proposal: ReminderProposal
    let onResolve: (Bool) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Review reminder") {
                    Text(proposal.reminder.title).font(.headline)
                    if !proposal.reminder.body.isEmpty { Text(proposal.reminder.body) }
                    Text(proposal.detail)
                }
                Section {
                    Button("Confirm and save") { onResolve(true) }
                    Button("Cancel", role: .cancel) { onResolve(false) }
                } footer: { Text("Nothing is scheduled until you confirm. Cancel to change the request.") }
            }.navigationTitle("Confirm reminder")
        }.tint(Color(hex: "#315E73"))
    }
}

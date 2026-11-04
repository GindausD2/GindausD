import Foundation
import Combine

struct LifeEvent: Identifiable, Codable {
    var id = UUID().uuidString
    var title: String
    var person: String
    var place: String
    var occurredAt: Date
    var notes: String
    var attended = false
    var source = "User-reviewed memory"
    var sourceExcerpt = "Details reviewed and saved by you."
    var updatedAt = Date()
    var hiddenReplaySections: [String]? = nil

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 160 && person.count <= 200 && place.count <= 300 && notes.count <= 2000 && source.count <= 300 && sourceExcerpt.count <= 2000 && (!attended || occurredAt <= Date())
    }

    static func matching(_ events: [LifeEvent], query: String, from: Date? = nil, to: Date? = nil) -> [LifeEvent] {
        let ignored: Set<String> = ["who", "did", "i", "meet", "met", "at", "the", "a", "an", "with", "about", "my", "was", "where", "when"]
        let terms = query.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { !ignored.contains($0) }
        return events.filter { event in
            guard from == nil || event.occurredAt >= from!, to == nil || event.occurredAt < to! else { return false }
            let text = [event.title, event.person, event.place, event.notes].joined(separator: " ")
            return terms.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }.sorted { $0.occurredAt > $1.occurredAt }
    }
}

struct LifeEventProposal: Identifiable {
    let id = UUID()
    let event: LifeEvent
    let scope: String
}

@MainActor
final class LifeMemoryApproval: ObservableObject {
    static let shared = LifeMemoryApproval()
    @Published private(set) var pending: LifeEventProposal?
    private var waiter: CheckedContinuation<String?, Never>?

    func propose(_ event: LifeEvent, scope: String) async -> String? {
        guard event.isValid, pending == nil, !Task.isCancelled, StorageService.shared.accountScope == scope, StorageService.shared.usesSavedMemory else { return nil }
        let proposal = LifeEventProposal(event: event, scope: scope)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(returning: nil); return }
                waiter = continuation; pending = proposal
            }
        } onCancel: { Task { @MainActor [weak self] in self?.resolve(id: proposal.id, savedID: nil) } }
    }

    func resolve(id: UUID, savedID: String?) {
        guard let proposal = pending, proposal.id == id else { return }
        let store = StorageService.shared
        let result = store.accountScope == proposal.scope && store.usesSavedMemory && savedID == proposal.event.id && store.loadLifeEvents().contains(where: { $0.id == savedID }) ? savedID : nil
        pending = nil; let continuation = waiter; waiter = nil
        continuation?.resume(returning: result)
    }
    func cancel() { if let id = pending?.id { resolve(id: id, savedID: nil) } }
}

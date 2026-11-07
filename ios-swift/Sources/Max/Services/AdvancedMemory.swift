import Foundation
import Combine

struct FactRevision: Codable, Equatable {
    let value: String
    let updatedAt: Date
    let source: String?
    let supersededAt: Date
}

struct FactLedger: Codable {
    var facts: [UserMemory]
    var transcriptCutoff: Date? = nil
    var generation: UUID? = nil
}

struct FactProposal: Identifiable {
    let id = UUID()
    let account: String
    let key: String
    let project: String?
    let value: String
    let previous: UserMemory?
    let generation: UUID?
}

enum FactResolution {
    case review(FactProposal)
    case clarify(String)
}

enum MemoryIdentity {
    static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }

    static func key(_ value: String) -> String {
        let normalized = normalize(value)
        switch normalized {
        case "database", "database engine", "database system", "database technology", "database stack": return "database"
        case "architecture", "project architecture", "technical architecture": return "architecture"
        case "job", "current job", "job title", "work role", "current role": return "job"
        case "working hours", "work hours", "working schedule", "work schedule": return "work schedule"
        default: return normalized
        }
    }

    static func mentions(_ name: String, in text: String) -> Bool {
        let name = normalize(name)
        return !name.isEmpty && (" " + normalize(text) + " ").contains(" " + name + " ")
    }

    static func requestsHistory(_ text: String) -> Bool {
        ["before", "previously", "previous version", "used to", "historical", "history", "old version"]
            .contains { mentions($0, in: text) }
    }
}

@MainActor
final class FactApproval: ObservableObject {
    static let shared = FactApproval()
    @Published private(set) var pending: FactProposal?
    private var waiter: CheckedContinuation<String?, Never>?

    func request(_ proposal: FactProposal) async -> String? {
        guard pending == nil, StorageService.shared.accountScope == proposal.account else { return nil }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(returning: nil); return }
                waiter = continuation
                pending = proposal
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(id: proposal.id, value: nil) }
        }
    }

    func finish(id: UUID, value: String?) {
        guard let proposal = pending, proposal.id == id else { return }
        let result = value.flatMap { StorageService.shared.saveApprovedFact(proposal, value: $0) }
        pending = nil
        let continuation = waiter
        waiter = nil
        continuation?.resume(returning: result)
    }

    func cancel() {
        if let pending { finish(id: pending.id, value: nil) }
    }
}

import Foundation

enum FollowUps {
    enum MeetingMatch {
        case linked(LifeEvent)
        case none
        case ambiguous
    }

    static func meeting(for person: String, events: [LifeEvent], now: Date = Date()) -> MeetingMatch {
        let matches = events.filter {
            $0.occurredAt <= now && MemoryIdentity.mentions(person, in: $0.person)
        }
        let exact = matches.filter { MemoryIdentity.normalize($0.person) == MemoryIdentity.normalize(person) }
        let candidates = exact.isEmpty ? matches : exact
        guard Set(candidates.map { MemoryIdentity.normalize($0.person) }).count <= 1 else { return .ambiguous }
        let ordered = candidates.sorted {
            if $0.attended != $1.attended { return $0.attended }
            return $0.occurredAt == $1.occurredAt ? $0.id < $1.id : $0.occurredAt > $1.occurredAt
        }
        return ordered.first.map(MeetingMatch.linked) ?? .none
    }

    static func requestedPerson(_ question: String) -> String? {
        let text = MemoryIdentity.normalize(question)
        let prefixes = ["what do i owe ", "what do i still owe ", "what did i promise ",
                        "what follow ups do i have for ", "show my follow ups with "]
        guard let prefix = prefixes.first(where: { text.hasPrefix($0) }) else { return nil }
        let name = String(text.dropFirst(prefix.count))
        return name.isEmpty ? nil : name
    }

    static func open(for person: String, reminders: [Reminder]) -> [Reminder] {
        let matches = reminders.filter {
            $0.completedAt == nil && MemoryIdentity.mentions(person, in: $0.followUpPerson ?? "")
        }
        let exact = matches.filter { MemoryIdentity.normalize($0.followUpPerson ?? "") == MemoryIdentity.normalize(person) }
        return (exact.isEmpty ? matches : exact).sorted {
            $0.fireDate == $1.fireDate ? $0.id < $1.id : $0.fireDate < $1.fireDate
        }
    }
}

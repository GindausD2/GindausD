import Foundation

enum PeopleRecall {
    struct Answer {
        let text: String
        var eventID: String? = nil
        var choices: [String] = []
    }

    static func answer(_ question: String, events: [LifeEvent], previousChoices: [String] = [],
                       now: Date = Date(), calendar: Calendar = .current) -> Answer? {
        let text = MemoryIdentity.normalize(question)
        let prefixes = ["who did i meet", "who did we meet", "who did i talk to", "who was i meeting",
                        "who did i have a meeting with", "who was the person i met",
                        "what was the name of the person i met", "what was the name of the guy i met",
                        "what was the name of the guy i had a meeting with", "what s the name of the person i met",
                        "what was the name of the person i had a meeting with"]
        if let prefix = prefixes.first(where: { text == $0 || text.hasPrefix($0 + " ") }) {
            let remainder = String(text.dropFirst(prefix.count))
            return lookup(remainder, events: events, now: now, calendar: calendar)
        }
        guard !previousChoices.isEmpty else { return nil }
        let selection = text.hasPrefix("option ") ? String(text.dropFirst(7)) : text
        if let index = Int(selection), index > 0, index <= previousChoices.count {
            let id = previousChoices[index - 1]
            guard let event = events.first(where: { $0.id == id }) else {
                return Answer(text: "That saved meeting is no longer available.")
            }
            return describe(event)
        }
        let matches = events.filter { previousChoices.contains($0.id) && MemoryIdentity.normalize($0.person) == selection }
        if matches.count == 1, let match = matches.first { return describe(match) }
        if matches.count > 1 { return clarify(matches) }
        return nil
    }

    private static func lookup(_ remainder: String, events: [LifeEvent], now: Date, calendar: Calendar) -> Answer {
        var detail = remainder
        var interval: DateInterval?
        let periods: [(String, Calendar.Component, Int)] = [
            ("a couple of months ago", .month, -2), ("two months ago", .month, -2),
            ("last month", .month, -1), ("this month", .month, 0),
            ("last week", .weekOfYear, -1), ("this week", .weekOfYear, 0),
            ("yesterday", .day, -1), ("today", .day, 0)
        ]
        for (phrase, component, offset) in periods where MemoryIdentity.mentions(phrase, in: detail) {
            if let date = calendar.date(byAdding: component, value: offset, to: now) {
                interval = calendar.dateInterval(of: component, for: date)
            }
            detail = detail.replacingOccurrences(of: phrase, with: " ")
            break
        }
        let ignored: Set<String> = ["at", "in", "the", "a", "an", "with", "about", "for", "that", "to", "there", "meeting", "restaurant"]
        let terms = detail.split(separator: " ").map(String.init).filter { !ignored.contains($0) }
        let matches = events.filter { event in
            guard !event.person.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  event.occurredAt <= now else { return false }
            if let interval, !(event.occurredAt >= interval.start && event.occurredAt < interval.end) { return false }
            let saved = [event.place, event.title, event.notes, event.person].joined(separator: " ")
            return terms.allSatisfy { MemoryIdentity.mentions($0, in: saved) }
        }.sorted { $0.occurredAt > $1.occurredAt }

        if matches.count == 1, let match = matches.first { return describe(match) }
        if !matches.isEmpty { return clarify(matches) }
        return Answer(text: "I couldn’t find a matching meeting in Life Memory. Try a different place or date, or review a past calendar meeting in Your Space → Memory → Life Memory.")
    }

    private static func clarify(_ matches: [LifeEvent]) -> Answer {
        let shown = Array(matches.prefix(5))
        let options = shown.enumerated().map { offset, event in
            "\(offset + 1). \(event.title) · \(event.occurredAt.formatted(date: .abbreviated, time: .omitted))"
        }.joined(separator: "\n")
        let more = matches.count > shown.count ? "\nMore meetings match. Add a place or date to narrow it down." : ""
        return Answer(text: "Which saved meeting do you mean? Reply with a number.\n\n" + options + more,
                      choices: shown.map(\.id))
    }

    private static func describe(_ event: LifeEvent) -> Answer {
        let place = event.place.isEmpty ? "" : " at \(event.place)"
        let date = event.occurredAt.formatted(date: .abbreviated, time: .omitted)
        let summary = event.attended
            ? "You saved that you met \(event.person)\(place) on \(date)."
            : "You had a meeting scheduled with \(event.person)\(place) on \(date). Your saved record doesn’t confirm that you met."
        let note = event.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return Answer(text: summary + (note.isEmpty ? "" : "\n\nSaved notes: " + String(note.prefix(400)) + (note.count > 400 ? "…" : "")),
                      eventID: event.id)
    }
}

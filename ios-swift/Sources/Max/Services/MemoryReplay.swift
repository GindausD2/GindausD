import Foundation

struct MemoryReplayCard: Identifiable, Equatable {
    let id: String
    let title: String
    let text: String
    let symbol: String
    let hideable: Bool
}

enum MemoryReplay {
    static func cards(for event: LifeEvent, locale: Locale = .current, timeZone: TimeZone = .current) -> [MemoryReplayCard] {
        let formatter = DateFormatter(); formatter.locale = locale; formatter.timeZone = timeZone
        formatter.dateStyle = .long; formatter.timeStyle = .short
        let status = event.attended ? "You confirmed this meeting happened." : "This is a planned event. Attendance has not been confirmed."
        var cards = [MemoryReplayCard(id: "event", title: event.title, text: formatter.string(from: event.occurredAt) + "\n" + timeZone.identifier + "\n\n" + status, symbol: "calendar", hideable: false)]
        if !event.person.isEmpty { cards.append(MemoryReplayCard(id: "people", title: "People recorded", text: event.person, symbol: "person.2", hideable: true)) }
        if !event.place.isEmpty { cards.append(MemoryReplayCard(id: "place", title: "Place recorded", text: event.place, symbol: "mappin", hideable: true)) }
        if !event.notes.isEmpty { cards.append(MemoryReplayCard(id: "notes", title: "Your saved notes", text: event.notes, symbol: "text.alignleft", hideable: true)) }
        cards.append(MemoryReplayCard(id: "source", title: "Supporting source", text: event.source + "\n\n" + event.sourceExcerpt, symbol: "doc.text.magnifyingglass", hideable: false))
        let hidden = Set(event.hiddenReplaySections ?? [])
        return cards.filter { !$0.hideable || !hidden.contains($0.id) }
    }
}

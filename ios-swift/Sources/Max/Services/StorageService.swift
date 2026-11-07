import Foundation
import UIKit

@MainActor
final class StorageService {
    static let shared = StorageService()

    private let messagesKey    = "max:messages"
    private let settingsKey    = "max:settings"
    private let notesKey       = "max:notes"
    private let memoriesKey    = "max:memories"
    private let memoryCardsKey = "max:memorycards"
    private let placeVisitsKey = "max:placevisits"
    private let remindersKey       = "max:reminders"
    private let profilePhotoKey    = "max:profilePhoto"
    private let conversationsKey   = "max:conversations"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    var accountScope: String { UserDefaults.standard.string(forKey: "max.storage.scope") ?? "demo" }
    func setAccountScope(_ scope: String) { UserDefaults.standard.set(scope, forKey: "max.storage.scope") }
    private func scoped(_ key: String, scope: String? = nil) -> String { "max.account.\(scope ?? accountScope).\(key)" }
    private func readData(for key: String, scope: String? = nil) -> Data? {
        let target = scope ?? accountScope
        let current = UserDefaults.standard.data(forKey: scoped(key, scope: target))
        // Legacy unscoped data is visible only to the local demo, never another account.
        return current ?? (target == "demo" ? UserDefaults.standard.data(forKey: key) : nil)
    }
    private func removeData(for key: String) {
        UserDefaults.standard.removeObject(forKey: scoped(key))
        if accountScope == "demo" { UserDefaults.standard.removeObject(forKey: key) }
    }

    // MARK: - Messages
    var usesSavedMemory: Bool { loadSettings().memoryEnabled ?? true }

    func loadLifeEvents() -> [LifeEvent] {
        guard let data = readData(for: "max:lifeEvents"), let values = try? decoder.decode([LifeEvent].self, from: data) else { return [] }
        return values
    }

    @discardableResult
    func saveLifeEvent(_ event: LifeEvent, scope: String, replacing: Bool = false) -> Bool {
        guard accountScope == scope, usesSavedMemory, event.isValid else { return false }
        var values = loadLifeEvents()
        if let index = values.firstIndex(where: { $0.id == event.id }) {
            guard replacing else { return false }
            values[index] = event
        } else {
            guard !replacing, values.count < 1000 else { return false }
            values.append(event)
        }
        guard let data = try? encoder.encode(values) else { return false }
        UserDefaults.standard.set(data, forKey: scoped("max:lifeEvents")); return true
    }

    @discardableResult
    func forgetLifeEvent(id: String, scope: String) -> Bool {
        guard accountScope == scope else { return false }
        var values = loadLifeEvents()
        guard values.contains(where: { $0.id == id }) else { return false }
        values.removeAll { $0.id == id }
        guard let data = try? encoder.encode(values) else { return false }
        UserDefaults.standard.set(data, forKey: scoped("max:lifeEvents")); return true
    }

    func setMemoryEnabled(_ enabled: Bool, accountScope expected: String) {
        guard accountScope == expected else { return }
        var settings = loadSettings(); settings.memoryEnabled = enabled; saveSettings(settings)
    }

    nonisolated static func dayKey(at date: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    func loadPriorities(day: String = StorageService.dayKey()) -> [DailyPriority] {
        guard let data = readData(for: "max:priorities"), let values = try? decoder.decode([DailyPriority].self, from: data) else { return [] }
        return values.filter { $0.day == day }
    }

    @discardableResult
    func savePriorities(_ values: [DailyPriority], day: String, accountScope expected: String) -> Bool {
        guard accountScope == expected, values.count <= 3, values.allSatisfy({ $0.day == day && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.title.count <= 160 }),
              Set(values.map(\.id)).count == values.count else { return false }
        var all = (readData(for: "max:priorities").flatMap { try? decoder.decode([DailyPriority].self, from: $0) }) ?? []
        all.removeAll { $0.day == day }; all.append(contentsOf: values)
        guard let data = try? encoder.encode(Array(all.suffix(93))) else { return false }
        UserDefaults.standard.set(data, forKey: scoped("max:priorities")); return true
    }

    func loadVocabulary() -> [String] {
        guard let data = readData(for: "max:vocabulary"), let words = try? decoder.decode([String].self, from: data) else { return [] }
        return words
    }

    @discardableResult
    func saveVocabulary(_ words: [String], accountScope expected: String) -> Bool {
        guard accountScope == expected, words.count <= 25,
              words.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 64 && $0.rangeOfCharacter(from: CharacterSet(charactersIn: "<>\r\n").union(.controlCharacters)) == nil }),
              Set(words.map { $0.lowercased() }).count == words.count, let data = try? encoder.encode(words) else { return false }
        UserDefaults.standard.set(data, forKey: scoped("max:vocabulary")); return true
    }

    @discardableResult
    func updateReminder(_ reminder: Reminder, accountScope expected: String) -> Bool {
        guard accountScope == expected else { return false }
        var values = loadReminders()
        guard let index = values.firstIndex(where: { $0.id == reminder.id }), let data = try? encoder.encode(values.enumerated().map { $0.offset == index ? reminder : $0.element }) else { return false }
        UserDefaults.standard.set(data, forKey: scoped(remindersKey)); return true
    }

    func loadMessages() -> [Message] {
        guard let data = readData(for: messagesKey),
              let messages = try? decoder.decode([Message].self, from: data)
        else { return [] }
        return messages
    }

    func saveMessages(_ messages: [Message]) {
        var storable = messages
        storable = storable.map {
            var m = $0
            m.isStreaming = false
            return m
        }
        if let data = try? encoder.encode(storable) {
            UserDefaults.standard.set(data, forKey: scoped(messagesKey))
        }
    }

    func clearMessages() {
        removeData(for: messagesKey)
    }

    // MARK: - Settings

    func loadSettings() -> AppSettings {
        guard let data = readData(for: settingsKey),
              let settings = try? decoder.decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: scoped(settingsKey))
        }
    }

    // MARK: - Notes

    func loadNotes() -> [Note] {
        guard let data = readData(for: notesKey),
              let notes = try? decoder.decode([Note].self, from: data)
        else { return [] }
        return notes
    }

    func saveNotes(_ notes: [Note]) {
        if let data = try? encoder.encode(notes) {
            UserDefaults.standard.set(data, forKey: scoped(notesKey))
        }
    }

    @discardableResult
    func saveNote(title: String, content: String) -> Note {
        var notes = loadNotes()
        let note = Note(title: title, content: content)
        notes.append(note)
        saveNotes(notes)
        return note
    }

    @discardableResult
    func deleteNote(id: String, accountScope expectedScope: String? = nil) -> Bool {
        guard expectedScope == nil || expectedScope == accountScope else { return false }
        var notes = loadNotes()
        guard notes.contains(where: { $0.id == id }) else { return false }
        notes.removeAll { $0.id == id }
        saveNotes(notes)
        return true
    }

    @discardableResult
    func updateNote(id: String, title: String? = nil, content: String? = nil, accountScope expectedScope: String? = nil) -> Bool {
        guard expectedScope == nil || expectedScope == accountScope else { return false }
        if let title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if let content, content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        var notes = loadNotes()
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return false }
        if let title { notes[idx].title = title.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let content { notes[idx].content = content.trimmingCharacters(in: .whitespacesAndNewlines) }
        notes[idx].updatedAt = Date()
        saveNotes(notes)
        return true
    }

    // MARK: - Memories

    private var factLedgerKey: String { "max:factLedgerV2" }

    private func factLedger() -> FactLedger? {
        if let data = readData(for: factLedgerKey) {
            return try? JSONDecoder().decode(FactLedger.self, from: data)
        }
        guard let data = readData(for: memoriesKey) else { return FactLedger(facts: []) }
        guard let legacy = try? decoder.decode([UserMemory].self, from: data) else { return nil }
        return FactLedger(facts: legacy)
    }

    private func writeFacts(_ ledger: FactLedger) -> Bool {
        guard let data = try? JSONEncoder().encode(ledger) else { return false }
        let key = scoped(factLedgerKey)
        UserDefaults.standard.set(data, forKey: key)
        guard UserDefaults.standard.data(forKey: key) == data else { return false }
        removeData(for: memoriesKey)
        return true
    }

    var memoryGeneration: UUID? { factLedger()?.generation }

    func recallFacts() -> [UserMemory] { factLedger()?.facts ?? [] }

    // Reviewed changes invalidate old prompt context without deleting the visible chat.
    func chatContext(_ messages: [Message]) -> [Message] {
        guard let latest = messages.lastIndex(where: { $0.role == "user" }) else { return messages }
        if isProjectMemoryQuestion(messages[latest].content) { return [messages[latest]] }
        guard let cutoff = factLedger()?.transcriptCutoff else { return messages }
        return messages.enumerated().compactMap { index, message in
            index == latest || message.timestamp > cutoff ? message : nil
        }
    }

    func resolveFact(key: String, value: String, project: String?, userText: String? = nil) -> FactResolution {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonicalKey = MemoryIdentity.key(key)
        let project = project?.trimmingCharacters(in: .whitespacesAndNewlines)
        let scope = project.flatMap { MemoryIdentity.normalize($0).isEmpty ? nil : $0 }
        guard !canonicalKey.isEmpty, key.count <= 120, !value.isEmpty, value.count <= 2000,
              (scope?.count ?? 0) <= 120 else {
            return .clarify("What exact fact would you like me to remember?")
        }

        let facts = recallFacts()
        let allProjects = Array(Set(facts.compactMap(\.project))).sorted()
        var candidates = facts.filter { MemoryIdentity.key($0.key) == canonicalKey }
        let wantsProject = userText.map { MemoryIdentity.mentions("project", in: $0) || MemoryIdentity.mentions("this app", in: $0) } ?? false
        let namedScope = scope.flatMap { name in
            userText == nil || MemoryIdentity.mentions(name, in: userText ?? "") ? name : nil
        }
        let mentionedProjects = userText.map { text in allProjects.filter { MemoryIdentity.mentions($0, in: text) } } ?? []
        if mentionedProjects.count > 1 {
            return .clarify("Which project should I update: \(mentionedProjects.joined(separator: ", "))?")
        }
        let inferredScope = namedScope ?? mentionedProjects.first
        if let inferredScope {
            candidates = candidates.filter { MemoryIdentity.normalize($0.project ?? "") == MemoryIdentity.normalize(inferredScope) }
        } else if wantsProject || scope != nil {
            candidates = candidates.filter { $0.project != nil }
            if allProjects.count > 1 {
                return .clarify("Which project should I update: \(allProjects.joined(separator: ", "))?")
            }
            if allProjects.isEmpty {
                return .clarify("What is the name of the project I should remember this for?")
            }
        } else if userText == nil {
            candidates = candidates.filter { $0.project == nil }
        }
        guard candidates.count <= 1 else {
            let labels = Array(Set(candidates.map(\.scopeLabel))).sorted()
            return .clarify("Which saved fact should I update? \(labels.joined(separator: ", ")). You can also choose it directly in Your Space → Memory.")
        }
        let previous = candidates.first
        let destination = previous?.project ?? inferredScope ?? ((wantsProject || scope != nil) ? allProjects.first : nil)
        return .review(FactProposal(account: accountScope, key: previous?.key ?? key, project: destination,
                                    value: value, previous: previous, generation: memoryGeneration))
    }

    func saveApprovedFact(_ proposal: FactProposal, value: String, source: String = "Reviewed in chat") -> String? {
        guard accountScope == proposal.account, usesSavedMemory, memoryGeneration == proposal.generation else { return nil }
        return writeFact(key: proposal.key, value: value, project: proposal.project, replacing: proposal.previous?.id, source: source)
    }

    private func writeFact(key: String, value: String, project: String?, replacing id: String?, source: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 2000, var ledger = factLedger() else { return nil }
        let now = Date()
        var fact: UserMemory
        if let id {
            guard let index = ledger.facts.firstIndex(where: { $0.id == id }) else { return nil }
            fact = ledger.facts[index]
            if fact.value != value {
                let revision = FactRevision(value: fact.value, updatedAt: fact.updatedAt, source: fact.source, supersededAt: now)
                fact.revisions = (fact.revisions ?? []) + [revision]
                fact.value = value
                ledger.transcriptCutoff = now
            }
            fact.updatedAt = now
            fact.source = source
            ledger.facts[index] = fact
        } else {
            guard !ledger.facts.contains(where: {
                MemoryIdentity.key($0.key) == MemoryIdentity.key(key) &&
                MemoryIdentity.normalize($0.project ?? "") == MemoryIdentity.normalize(project ?? "")
            }) else { return nil }
            fact = UserMemory(key: key, value: value, updatedAt: now, recordID: UUID().uuidString, project: project, source: source)
            ledger.facts.append(fact)
            ledger.transcriptCutoff = now
        }
        ledger.generation = UUID()
        return writeFacts(ledger) ? fact.id : nil
    }

    func rememberFact(key: String, value: String) {
        if case .review(let proposal) = resolveFact(key: key, value: value, project: nil) {
            _ = writeFact(key: proposal.key, value: value, project: proposal.project, replacing: proposal.previous?.id, source: "Saved fact")
        }
    }

    func clearMemories() {
        _ = writeFacts(FactLedger(facts: [], transcriptCutoff: Date(), generation: UUID()))
    }

    func updateFact(id: String, value: String, accountScope expected: String) -> Bool {
        guard expected == accountScope, let fact = recallFacts().first(where: { $0.id == id }) else { return false }
        return writeFact(key: fact.key, value: value, project: fact.project, replacing: id, source: "Edited in Memory") != nil
    }

    func updateFact(key: String, value: String, accountScope expectedScope: String) -> Bool {
        let matches = recallFacts().filter { $0.key.caseInsensitiveCompare(key) == .orderedSame }
        guard matches.count == 1, let fact = matches.first else { return false }
        return updateFact(id: fact.id, value: value, accountScope: expectedScope)
    }

    func forgetFact(id: String, accountScope expected: String) -> Bool {
        guard expected == accountScope, var ledger = factLedger(),
              let index = ledger.facts.firstIndex(where: { $0.id == id }) else { return false }
        ledger.facts.remove(at: index)
        ledger.transcriptCutoff = Date()
        ledger.generation = UUID()
        return writeFacts(ledger)
    }

    func forgetFact(key: String, accountScope expectedScope: String) -> Bool {
        let matches = recallFacts().filter { $0.key.caseInsensitiveCompare(key) == .orderedSame }
        guard matches.count == 1, let fact = matches.first else { return false }
        return forgetFact(id: fact.id, accountScope: expectedScope)
    }

    func memoryLookup(project: String?, userText: String) -> [UserMemory] {
        guard usesSavedMemory else { return [] }
        let facts = recallFacts()
        let projects = Set(facts.compactMap(\.project))
        let mentioned = projects.filter { MemoryIdentity.mentions($0, in: userText) }
        if mentioned.count > 1 { return [] }
        if let name = mentioned.first {
            return facts.filter { MemoryIdentity.normalize($0.project ?? "") == MemoryIdentity.normalize(name) }
        }
        if let project {
            // A tool cannot select an unmentioned project when several are possible.
            guard projects.count == 1, let only = projects.first,
                  MemoryIdentity.normalize(only) == MemoryIdentity.normalize(project),
                  ["my project", "this project", "the project"].contains(where: { MemoryIdentity.mentions($0, in: userText) }) else { return [] }
            return facts.filter { MemoryIdentity.normalize($0.project ?? "") == MemoryIdentity.normalize(only) }
        }
        if MemoryIdentity.mentions("project", in: userText) {
            guard ["my project", "this project", "the project"].contains(where: { MemoryIdentity.mentions($0, in: userText) }),
                  projects.count == 1, let only = projects.first else { return [] }
            return facts.filter { MemoryIdentity.normalize($0.project ?? "") == MemoryIdentity.normalize(only) }
        }
        return facts.filter { $0.project == nil }
    }

    func isProjectMemoryQuestion(_ text: String) -> Bool {
        let normalized = MemoryIdentity.normalize(text)
        guard ["what ", "which ", "how ", "where ", "when ", "why "].contains(where: normalized.hasPrefix) else { return false }
        return MemoryIdentity.mentions("project", in: text)
            || recallFacts().compactMap(\.project).contains { MemoryIdentity.mentions($0, in: text) }
    }

    func answerKnownFact(_ question: String) -> (String, [String])? {
        guard usesSavedMemory else { return nil }
        let normalized = MemoryIdentity.normalize(question)
        guard ["what ", "which ", "who ", "where ", "when "].contains(where: normalized.hasPrefix),
              !["should", "next", "try", "remember"].contains(where: { MemoryIdentity.mentions($0, in: question) }) else { return nil }
        let facts = memoryLookup(project: nil, userText: question)
        let exact = facts.filter { MemoryIdentity.mentions($0.key, in: question) }
        let canonicalKeys = ["database", "architecture", "job", "work schedule"]
        let subject = canonicalKeys.first { MemoryIdentity.mentions($0, in: question) }
            ?? (MemoryIdentity.mentions("working hours", in: question) ? "work schedule" : nil)
        var matches = subject.map { key in facts.filter { MemoryIdentity.key($0.key) == key } } ?? exact
        if matches.isEmpty, subject == nil, normalized.contains(" use") || normalized.contains(" uses"),
           facts.contains(where: { $0.project != nil }) {
            matches = facts.filter { MemoryIdentity.key($0.key) == "database" }
        }
        if matches.count > 1 { return ("I found conflicting saved facts. Which one should I use?", []) }
        guard let fact = matches.first else { return nil }
        if MemoryIdentity.requestsHistory(question) {
            guard let old = fact.revisions?.last else {
                return ("I don’t have an earlier version saved. The current value in Memory is \(fact.value).", [fact.id])
            }
            return ("Previously, Memory had \(old.value) for \(fact.scopeLabel) · \(fact.key). That version is no longer current. The current value is \(fact.value).", [fact.id])
        }
        return ("From Memory · \(fact.scopeLabel) · \(fact.key): \(fact.value)", [fact.id])
    }

    // MARK: - MemoryCards

    func loadMemoryCards() -> [MemoryCard] {
        guard let data = readData(for: memoryCardsKey),
              let cards = try? decoder.decode([MemoryCard].self, from: data)
        else { return [] }
        return cards
    }

    func saveMemoryCards(_ cards: [MemoryCard]) {
        if let data = try? encoder.encode(cards) {
            UserDefaults.standard.set(data, forKey: scoped(memoryCardsKey))
        }
    }

    @discardableResult
    func saveMemoryCard(_ card: MemoryCard, accountScope expectedScope: String) -> Bool {
        guard expectedScope == accountScope, !card.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        var cards = loadMemoryCards()
        guard !cards.contains(where: { $0.id == card.id }) else { return false }
        cards.append(card); saveMemoryCards(cards)
        return true
    }

    @discardableResult
    func updateMemoryCard(id: String, content: String, category: MemoryCategory, accountScope expectedScope: String) -> Bool {
        guard expectedScope == accountScope else { return false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        var cards = loadMemoryCards()
        guard !trimmed.isEmpty, let index = cards.firstIndex(where: { $0.id == id }) else { return false }
        cards[index].content = trimmed; cards[index].category = category; cards[index].updatedAt = Date()
        saveMemoryCards(cards)
        return true
    }

    @discardableResult
    func deleteMemoryCard(id: String, accountScope expectedScope: String? = nil) -> Bool {
        guard expectedScope == nil || expectedScope == accountScope else { return false }
        var cards = loadMemoryCards()
        guard cards.contains(where: { $0.id == id }) else { return false }
        cards.removeAll { $0.id == id }
        saveMemoryCards(cards)
        return true
    }

    // MARK: - Place Visits

    func loadPlaceVisits(scope: String? = nil) -> [PlaceVisit] {
        guard let data = readData(for: placeVisitsKey, scope: scope),
              let visits = try? decoder.decode([PlaceVisit].self, from: data)
        else { return [] }
        return visits
    }

    func savePlaceVisit(_ visit: PlaceVisit, scope: String? = nil) {
        var visits = loadPlaceVisits(scope: scope)
        visits.append(visit)
        if visits.count > 100 { visits = Array(visits.suffix(100)) }
        if let data = try? encoder.encode(visits) {
            UserDefaults.standard.set(data, forKey: scoped(placeVisitsKey, scope: scope))
        }
    }

    func clearPlaceVisits() {
        removeData(for: placeVisitsKey)
    }

    // MARK: - Reminders

    func loadReminders(scope: String? = nil) -> [Reminder] {
        guard let data = readData(for: remindersKey, scope: scope),
              let reminders = try? decoder.decode([Reminder].self, from: data)
        else { return [] }
        return reminders
    }

    func saveReminder(_ reminder: Reminder, scope: String? = nil) {
        var reminders = loadReminders(scope: scope)
        reminders.append(reminder)
        if let data = try? encoder.encode(reminders) {
            UserDefaults.standard.set(data, forKey: scoped(remindersKey, scope: scope))
        }
    }

    func deleteReminder(id: String) {
        var reminders = loadReminders()
        reminders.removeAll { $0.id == id }
        if let data = try? encoder.encode(reminders) {
            UserDefaults.standard.set(data, forKey: scoped(remindersKey))
        }
    }

    // MARK: - Profile Photo

    func saveProfilePhoto(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(data, forKey: scoped(profilePhotoKey))
        }
    }

    func loadProfilePhoto() -> UIImage? {
        guard let data = readData(for: profilePhotoKey) else { return nil }
        return UIImage(data: data)
    }

    func clearProfilePhoto() {
        removeData(for: profilePhotoKey)
    }

    // MARK: - Conversations

    func loadConversations() -> [Conversation] {
        guard let data = readData(for: conversationsKey),
              let convs = try? decoder.decode([Conversation].self, from: data)
        else { return [] }
        return convs
    }

    func saveConversation(_ conversation: Conversation) {
        var convs = loadConversations()
        if let idx = convs.firstIndex(where: { $0.id == conversation.id }) {
            convs[idx] = conversation
        } else {
            convs.insert(conversation, at: 0)
        }
        if convs.count > 200 { convs = Array(convs.prefix(200)) }
        if let data = try? encoder.encode(convs) {
            UserDefaults.standard.set(data, forKey: scoped(conversationsKey))
        }
    }

    func deleteConversation(id: String) {
        var convs = loadConversations()
        convs.removeAll { $0.id == id }
        if let data = try? encoder.encode(convs) {
            UserDefaults.standard.set(data, forKey: scoped(conversationsKey))
        }
    }

    func clearAllConversations() {
        removeData(for: conversationsKey)
    }

    // MARK: - Clear All

    func clearAll() {
        removeData(for: "max:lifeEvents")
        removeData(for: "max:priorities")
        removeData(for: "max:vocabulary")
        clearMessages()
        clearMemories()
        removeData(for: notesKey)
        removeData(for: remindersKey)
    }
}


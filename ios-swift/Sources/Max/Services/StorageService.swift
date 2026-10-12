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

    func deleteNote(id: String) {
        var notes = loadNotes()
        notes.removeAll { $0.id == id }
        saveNotes(notes)
    }

    func updateNote(id: String, title: String? = nil, content: String? = nil) {
        var notes = loadNotes()
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            if let title = title { notes[idx].title = title }
            if let content = content { notes[idx].content = content }
            notes[idx].updatedAt = Date()
        }
        saveNotes(notes)
    }

    // MARK: - Memories

    func recallFacts() -> [UserMemory] {
        guard let data = readData(for: memoriesKey),
              let memories = try? decoder.decode([UserMemory].self, from: data)
        else { return [] }
        return memories
    }

    func rememberFact(key: String, value: String) {
        var memories = recallFacts()
        if let idx = memories.firstIndex(where: { $0.key.lowercased() == key.lowercased() }) {
            memories[idx] = UserMemory(key: key, value: value, updatedAt: Date())
        } else {
            memories.append(UserMemory(key: key, value: value, updatedAt: Date()))
        }
        if let data = try? encoder.encode(memories) {
            UserDefaults.standard.set(data, forKey: scoped(memoriesKey))
        }
    }

    func clearMemories() {
        removeData(for: memoriesKey)
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

    func deleteMemoryCard(id: String) {
        var cards = loadMemoryCards()
        cards.removeAll { $0.id == id }
        saveMemoryCards(cards)
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
        clearMessages()
        clearMemories()
        removeData(for: notesKey)
        removeData(for: remindersKey)
    }
}

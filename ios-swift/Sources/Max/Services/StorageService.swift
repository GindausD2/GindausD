import Foundation

final class StorageService {
    static let shared = StorageService()

    private let messagesKey    = "max:messages"
    private let settingsKey    = "max:settings"
    private let notesKey       = "max:notes"
    private let memoriesKey    = "max:memories"
    private let memoryCardsKey = "max:memorycards"
    private let placeVisitsKey = "max:placevisits"
    private let remindersKey   = "max:reminders"
    private let profilePhotoKey = "max:profilePhoto"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Messages

    func loadMessages() -> [Message] {
        guard let data = UserDefaults.standard.data(forKey: messagesKey),
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
            UserDefaults.standard.set(data, forKey: messagesKey)
        }
    }

    func clearMessages() {
        UserDefaults.standard.removeObject(forKey: messagesKey)
    }

    // MARK: - Settings

    func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? decoder.decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    // MARK: - Notes

    func loadNotes() -> [Note] {
        guard let data = UserDefaults.standard.data(forKey: notesKey),
              let notes = try? decoder.decode([Note].self, from: data)
        else { return [] }
        return notes
    }

    func saveNotes(_ notes: [Note]) {
        if let data = try? encoder.encode(notes) {
            UserDefaults.standard.set(data, forKey: notesKey)
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
        guard let data = UserDefaults.standard.data(forKey: memoriesKey),
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
            UserDefaults.standard.set(data, forKey: memoriesKey)
        }
    }

    func clearMemories() {
        UserDefaults.standard.removeObject(forKey: memoriesKey)
    }

    // MARK: - MemoryCards

    func loadMemoryCards() -> [MemoryCard] {
        guard let data = UserDefaults.standard.data(forKey: memoryCardsKey),
              let cards = try? decoder.decode([MemoryCard].self, from: data)
        else { return [] }
        return cards
    }

    func saveMemoryCards(_ cards: [MemoryCard]) {
        if let data = try? encoder.encode(cards) {
            UserDefaults.standard.set(data, forKey: memoryCardsKey)
        }
    }

    func deleteMemoryCard(id: String) {
        var cards = loadMemoryCards()
        cards.removeAll { $0.id == id }
        saveMemoryCards(cards)
    }

    // MARK: - Place Visits

    func loadPlaceVisits() -> [PlaceVisit] {
        guard let data = UserDefaults.standard.data(forKey: placeVisitsKey),
              let visits = try? decoder.decode([PlaceVisit].self, from: data)
        else { return [] }
        return visits
    }

    func savePlaceVisit(_ visit: PlaceVisit) {
        var visits = loadPlaceVisits()
        visits.append(visit)
        if visits.count > 100 { visits = Array(visits.suffix(100)) }
        if let data = try? encoder.encode(visits) {
            UserDefaults.standard.set(data, forKey: placeVisitsKey)
        }
    }

    func clearPlaceVisits() {
        UserDefaults.standard.removeObject(forKey: placeVisitsKey)
    }

    // MARK: - Reminders

    func loadReminders() -> [Reminder] {
        guard let data = UserDefaults.standard.data(forKey: remindersKey),
              let reminders = try? decoder.decode([Reminder].self, from: data)
        else { return [] }
        return reminders
    }

    func saveReminder(_ reminder: Reminder) {
        var reminders = loadReminders()
        reminders.append(reminder)
        if let data = try? encoder.encode(reminders) {
            UserDefaults.standard.set(data, forKey: remindersKey)
        }
    }

    func deleteReminder(id: String) {
        var reminders = loadReminders()
        reminders.removeAll { $0.id == id }
        if let data = try? encoder.encode(reminders) {
            UserDefaults.standard.set(data, forKey: remindersKey)
        }
    }

    // MARK: - Profile Photo

    func saveProfilePhoto(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(data, forKey: profilePhotoKey)
        }
    }

    func loadProfilePhoto() -> UIImage? {
        guard let data = UserDefaults.standard.data(forKey: profilePhotoKey) else { return nil }
        return UIImage(data: data)
    }

    func clearProfilePhoto() {
        UserDefaults.standard.removeObject(forKey: profilePhotoKey)
    }

    // MARK: - Clear All

    func clearAll() {
        clearMessages()
        clearMemories()
        UserDefaults.standard.removeObject(forKey: notesKey)
        UserDefaults.standard.removeObject(forKey: remindersKey)
    }
}

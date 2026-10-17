import Foundation

// MARK: - Message

struct Message: Identifiable, Codable {
    var id: String
    var role: String  // "user" | "assistant"
    var content: String
    var timestamp: Date
    var isStreaming: Bool = false

    init(id: String = UUID().uuidString, role: String, content: String, timestamp: Date = Date(), isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}

// MARK: - AuthUser

struct AuthUser: Codable, Equatable {
    var id: String? = nil
    var name: String?
    var email: String?
    var isDemo: Bool?
    var trialStartedAt: Date? = nil

    var storageScope: String { id ?? (isDemo == true ? "demo" : "signed-out") }

    var trialExpiresAt: Date? {
        guard isDemo == true, let trialStartedAt else { return nil }
        return trialStartedAt.addingTimeInterval(7 * 24 * 3600)
    }

    func demoIsExpired(at date: Date) -> Bool {
        guard isDemo == true else { return false }
        guard let expiry = trialExpiresAt else { return true }
        return date >= expiry
    }

    func allowsAccess(hasSubscription: Bool, at date: Date) -> Bool {
        isDemo == true ? !demoIsExpired(at: date) : hasSubscription
    }
}

// MARK: - AppSettings

struct AppSettings: Codable {
    var assistantName: String = "Max"
    var voiceEnabled: Bool = true
    var speakingHapticsEnabled: Bool? = true
    var userName: String = ""
    var colorScheme: String = "system"      // "system" | "light" | "dark"
    var continuousConversation: Bool? = false
    var preferredVoice: String = "female"   // "female" | "male"
    var shareAnalytics: Bool = false
    var personalisedSuggestions: Bool = true
    var briefingEnabled: Bool = false
    var briefingHour: Int = 8
    var briefingMinute: Int = 0
}

// MARK: - Note

struct Note: Identifiable, Codable {
    var id: String
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, title: String, content: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - UserMemory

struct UserMemory: Codable {
    var key: String
    var value: String
    var updatedAt: Date
}

// MARK: - PlaceVisit

struct PlaceVisit: Identifiable, Codable {
    var id: String
    var destination: String
    var person: String?
    var note: String?
    var visitedAt: Date
    var latitude: Double?
    var longitude: Double?

    init(id: String = UUID().uuidString, destination: String,
         person: String? = nil, note: String? = nil, visitedAt: Date = Date(), latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.destination = destination
        self.person = person
        self.note = note
        self.visitedAt = visitedAt
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - MemoryCard

enum MemoryCategory: String, Codable, CaseIterable {
    case personal, likes, hobbies, people, goals, other

    var label: String {
        switch self {
        case .personal:  return "Personal"
        case .likes:     return "Likes"
        case .hobbies:   return "Hobbies"
        case .people:    return "People"
        case .goals:     return "Goals"
        case .other:     return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .personal:  return "person.fill"
        case .likes:     return "heart.fill"
        case .hobbies:   return "paintbrush.fill"
        case .people:    return "person.2.fill"
        case .goals:     return "flag.fill"
        case .other:     return "folder.fill"
        }
    }

    var emptyTitle: String { "No \(label) Yet" }

    var emptySubtitle: String {
        switch self {
        case .personal:  return "Add things about yourself so Max can\ngive you better, personalized responses."
        case .likes:     return "Add things you like so Max can\ntailor its responses."
        case .hobbies:   return "Add your hobbies so Max can\nsuggest activities and topics you enjoy."
        case .people:    return "Add people in your life so Max can\nremember them."
        case .goals:     return "Add your goals so Max can\nhelp you achieve them."
        case .other:     return "Add other things about yourself so Max\ncan give you better responses."
        }
    }
}

struct MemoryCard: Identifiable, Codable {
    var id: String
    var category: MemoryCategory
    var content: String
    var createdAt: Date

    init(id: String = UUID().uuidString, category: MemoryCategory, content: String, createdAt: Date = Date()) {
        self.id = id
        self.category = category
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Reminder

struct Reminder: Identifiable, Codable {
    var id: String
    var title: String
    var body: String
    var fireDate: Date
    var createdAt: Date
    var triggerKind: String?
    var contextName: String?
    var placeID: String?

    func triggerSummary(place: PlaceVisit? = nil, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        if triggerKind == "location" {
            let prefix = "Arriving at "
            let fallback = body.hasPrefix(prefix) ? String(body.dropFirst(prefix.count)) : "your saved place"
            return "When iOS detects arrival at \(place?.destination ?? fallback)"
        }
        if triggerKind == "context" { return "When you check \(contextName ?? "this context") in Max" }
        let formatter = DateFormatter()
        formatter.locale = locale; formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMMdjmmz")
        return "At \(formatter.string(from: fireDate))"
    }

    init(id: String = UUID().uuidString, title: String, body: String, fireDate: Date, createdAt: Date = Date(), triggerKind: String? = nil, contextName: String? = nil, placeID: String? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.createdAt = createdAt
        self.triggerKind = triggerKind
        self.contextName = contextName
        self.placeID = placeID
    }
}

// MARK: - Conversation (saved history session)

struct Conversation: Identifiable, Codable {
    var id: String
    var title: String
    var messages: [Message]
    var startedAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, title: String, messages: [Message],
         startedAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    var assistantPreview: String {
        messages.first(where: { $0.role == "assistant" && !$0.content.isEmpty })
            .map { String($0.content.prefix(100)) } ?? ""
    }

    var userMessageCount: Int { messages.filter { $0.role == "user" }.count }
}

// MARK: - App State Enums

enum ConversationState: Equatable {
    case idle
    case listening
    case thinking
    case speaking
}

// MARK: - Claude API Request/Response Types

struct ClaudeMessage: Codable {
    var role: String
    var content: ClaudeContent
}

enum ClaudeContent: Codable {
    case text(String)
    case blocks([ContentBlock])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let blocks = try? container.decode([ContentBlock].self) {
            self = .blocks(blocks)
        } else {
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let str):
            try container.encode(str)
        case .blocks(let blocks):
            try container.encode(blocks)
        }
    }
}

struct ContentBlock: Codable {
    var type: String
    var id: String?
    var name: String?
    var input: [String: AnyCodable]?
    var text: String?
    var toolUseId: String?
    var content: String?

    enum CodingKeys: String, CodingKey {
        case type, id, name, input, text
        case toolUseId = "tool_use_id"
        case content
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Tool Definition

struct ToolDefinition: Codable {
    var name: String
    var description: String
    var inputSchema: InputSchema

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

struct InputSchema: Codable {
    var type: String
    var properties: [String: PropertyDefinition]
    var required: [String]?
}

struct PropertyDefinition: Codable {
    var type: String
    var description: String
}

// MARK: - System Prompt

let systemPrompt = """
You are Max, a warm and practical AI life companion. You help with notes, explicitly saved memories and places, reminders, and daily briefings.
Keep spoken replies short, natural, and personable. Ask a useful follow-up when needed. Ask before storing inferred personal details; save information when the user requests it.
Use tool results as the source of truth. Never pretend you have checked emails, weather, calendars, missed calls, or location when you have not. Explain unavailable sources briefly.
Resolve ambiguous reminder times, places, and contexts before scheduling. A context reminder is shown when the user explicitly checks that named context in Max; it does not continuously monitor their behavior.
V1 does not book flights, Uber rides, purchases, or run advanced autonomous agents.
Confirm success only after the tool reports success. Include the exact confirmed reminder date/time and time zone, saved arrival place, or explicit context from the tool result. Never describe a Maps search as a confirmed visit.
"""

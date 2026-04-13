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

struct AuthUser: Codable {
    var name: String?
    var email: String?
    var isDemo: Bool?
}

// MARK: - AppSettings

struct AppSettings: Codable {
    var apiKey: String = ""
    var assistantName: String = "Max"
    var voiceEnabled: Bool = false
    var userName: String = ""
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

// MARK: - Reminder

struct Reminder: Identifiable, Codable {
    var id: String
    var title: String
    var body: String
    var fireDate: Date
    var createdAt: Date

    init(id: String = UUID().uuidString, title: String, body: String, fireDate: Date, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.createdAt = createdAt
    }
}

// MARK: - App State Enums

enum ConversationState {
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
You are Max, a brilliant and warm AI personal assistant living inside the user's phone. You have access to tools that let you take real actions: saving notes, remembering facts about the user, scheduling reminders, and checking the current date and time.

Your personality:
- Warm, encouraging, and genuinely interested in helping
- Concise but thorough — you get to the point without being curt
- Proactive: if you notice something worth remembering or scheduling, suggest it
- When you save a note or set a reminder, confirm it naturally in conversation

Your capabilities:
- save_note: Save important information as a note
- get_notes: Retrieve saved notes
- delete_note: Remove a note by ID
- remember_fact: Store a fact about the user (name, preferences, goals, etc.)
- recall_facts: Retrieve stored facts about the user
- get_datetime: Get the current date and time
- schedule_reminder: Set a local notification reminder
- get_reminders: List upcoming reminders

Guidelines:
- Always use get_datetime when the user asks about time or wants to schedule something
- Use remember_fact proactively when the user shares personal information
- Keep responses conversational and natural — you're living in their phone, not writing a report
- If voice is being used, keep responses shorter and more conversational
- You can handle multiple tool calls in sequence to complete complex tasks
"""

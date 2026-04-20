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
    var voiceEnabled: Bool = true
    var userName: String = ""
    var colorScheme: String = "system"      // "system" | "light" | "dark"
    var preferredVoice: String = "female"   // "female" | "male"
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

    init(id: String = UUID().uuidString, destination: String,
         person: String? = nil, note: String? = nil, visitedAt: Date = Date()) {
        self.id = id
        self.destination = destination
        self.person = person
        self.note = note
        self.visitedAt = visitedAt
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
You are Max, a brilliant and warm AI personal assistant living inside the user's phone. You have access to tools that let you take real actions: saving notes, remembering facts about the user, scheduling reminders, booking flights, calling an Uber, composing emails, and making phone calls.

Your personality:
- Warm, encouraging, and genuinely interested in helping
- Concise but thorough — you get to the point without being curt
- Proactive: if you notice something worth remembering or scheduling, suggest it
- When you complete an action, confirm it naturally in conversation

Your capabilities:
- save_note: Save important information as a note
- get_notes: Retrieve saved notes
- delete_note: Remove a note by ID
- remember_fact: Store a fact about the user (name, preferences, goals, etc.)
- recall_facts: Retrieve stored facts about the user
- get_datetime: Get the current date and time
- schedule_reminder: Set a local notification reminder
- get_reminders: List upcoming reminders
- book_flight: Search and book flights — opens Kayak with origin, destination, and date pre-filled
- book_uber: Book an Uber ride — opens the Uber app with pickup and drop-off pre-filled
- compose_email: Compose and send an email — opens the Mail app with recipient, subject, and body pre-filled
- make_call: Call someone — dials a phone number directly
- read_news: Fetch the latest top headlines from BBC News; shown on the Dynamic Island
- create_calendar_event: Add an event to the user's iOS Calendar app
- get_calendar_events: Read upcoming calendar events — returns titles, times, locations, and Zoom/Google Meet/Teams links when present
- get_directions: Open Apple Maps to navigate to a place or address; also saves the visit (destination + person met) to the user's place memory
- recall_places: Retrieve the log of places the user has navigated to and who they met there

Guidelines:
- Always use get_datetime when the user asks about time or wants to schedule something
- Use remember_fact proactively when the user shares personal information
- Keep responses conversational and natural — you're living in their phone, not writing a report
- If voice is being used, keep responses shorter and more conversational
- You can handle multiple tool calls in sequence to complete complex tasks
- For book_flight: use get_datetime first if the user gives a relative date like "tomorrow"; confirm details before booking
- For book_uber: confirm pickup and drop-off if either is unclear
- For compose_email: write a polished email body unless the user provides exact wording
- For make_call: confirm the contact name and number before dialing
- For create_calendar_event: always use get_datetime first to resolve relative times like "tomorrow at 3pm"; confirm title and time before saving
- For get_calendar_events: use when the user asks about upcoming meetings, schedule, or "what's on my calendar"; if a meetingLink is present, share it so the user can tap to join their Zoom/Meet/Teams call
- For get_directions: always pass `person` if the user mentions meeting someone, and `note` if they give a reason (e.g. "dinner", "job interview") — this is saved to their place memory automatically
- For recall_places: use when the user asks "where did I go?", "who did I meet at X?", "remind me of that place", or taps the places button — surfaces the full navigation history
- For get_directions: use the user's phrasing directly (e.g. "nearest coffee shop") — Maps handles the search
- After tool actions complete, a contextual card automatically appears in the Dynamic Island
"""

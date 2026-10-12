import Foundation

// MARK: - Stream Chunk

enum StreamChunk {
    case text(String)
    case toolStart(String)      // tool name
    case toolDone
    case done
    case error(String)
}

// MARK: - SSE Parsing Helpers

private struct SSEEvent {
    var event: String?
    var data: String?
}

// MARK: - Claude API Request Bodies

private struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let stream: Bool
    let context: String
    let messages: [ClaudeRequestMessage]
    let tools: [ToolDefinition]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case stream, context, messages, tools
    }
}

private struct ClaudeRequestMessage: Encodable {
    let role: String
    let content: ClaudeRequestContent
}

private enum ClaudeRequestContent: Encodable {
    case string(String)
    case parts([ClaudeContentPart])   // multi-modal (text + image)
    case blocks([ClaudeRequestBlock])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):  try container.encode(s)
        case .parts(let p):   try container.encode(p)
        case .blocks(let b):  try container.encode(b)
        }
    }
}

// Encodes either a text or base-64 image part for vision messages
private enum ClaudeContentPart: Encodable {
    case text(String)
    case image(base64: String, mediaType: String)

    private enum CK: String, CodingKey { case type, text, source }
    private enum SK: String, CodingKey { case type, mediaType = "media_type", data }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        switch self {
        case .text(let t):
            try c.encode("text",  forKey: .type)
            try c.encode(t,       forKey: .text)
        case .image(let b64, let mime):
            try c.encode("image", forKey: .type)
            var s = c.nestedContainer(keyedBy: SK.self, forKey: .source)
            try s.encode("base64", forKey: .type)
            try s.encode(mime,     forKey: .mediaType)
            try s.encode(b64,      forKey: .data)
        }
    }
}

private struct ClaudeRequestBlock: Encodable {
    let type: String
    let toolUseId: String?
    let content: String?
    let id: String?
    let name: String?
    let input: [String: AnyCodable]?
    let text: String?

    enum CodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case content, id, name, input, text
    }

    init(type: String, toolUseId: String? = nil, content: String? = nil,
         id: String? = nil, name: String? = nil, input: [String: AnyCodable]? = nil, text: String? = nil) {
        self.type = type
        self.toolUseId = toolUseId
        self.content = content
        self.id = id
        self.name = name
        self.input = input
        self.text = text
    }
}

// MARK: - Tool Call accumulation

private struct AccumulatedToolCall {
    var id: String
    var name: String
    var inputJSON: String = ""
}

// MARK: - Claude Service

final class ClaudeService {
    static let shared = ClaudeService()


    private let apiVersion = "2023-06-01"
    private let modelID = "claude-sonnet-4-6"
    private let maxTokens = 4096

    private init() {}

    // MARK: - Tools Definition

    private var toolDefinitions: [ToolDefinition] {
        let definitions: [ToolDefinition] = [
            ToolDefinition(
                name: "get_datetime",
                description: "Get the current date and time.",
                inputSchema: InputSchema(type: "object", properties: [:], required: [])
            ),
            ToolDefinition(
                name: "save_note",
                description: "Save a note with a title and content.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "title": PropertyDefinition(type: "string", description: "Note title"),
                        "content": PropertyDefinition(type: "string", description: "Note content")
                    ],
                    required: ["title", "content"]
                )
            ),
            ToolDefinition(
                name: "get_notes",
                description: "Retrieve all saved notes.",
                inputSchema: InputSchema(type: "object", properties: [:], required: [])
            ),
            ToolDefinition(
                name: "delete_note",
                description: "Delete a note by its ID.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "id": PropertyDefinition(type: "string", description: "Note ID to delete")
                    ],
                    required: ["id"]
                )
            ),
            ToolDefinition(
                name: "remember_fact",
                description: "Remember a fact about the user for future reference.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "key": PropertyDefinition(type: "string", description: "Fact category/key"),
                        "value": PropertyDefinition(type: "string", description: "Fact value")
                    ],
                    required: ["key", "value"]
                )
            ),
            ToolDefinition(
                name: "recall_facts",
                description: "Recall all stored facts about the user.",
                inputSchema: InputSchema(type: "object", properties: [:], required: [])
            ),
            ToolDefinition(
                name: "schedule_reminder",
                description: "Schedule a reminder notification.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "title": PropertyDefinition(type: "string", description: "Reminder title"),
                        "body": PropertyDefinition(type: "string", description: "Reminder body text"),
                        "fireAt": PropertyDefinition(type: "string", description: "Future ISO8601 timestamp with timezone; provide this or minutesFromNow"),
                        "minutesFromNow": PropertyDefinition(type: "string", description: "Positive minutes from now; provide this or fireAt")
                    ],
                    required: ["title"]
                )
            ),
            ToolDefinition(
                name: "get_reminders",
                description: "Get all scheduled reminders.",
                inputSchema: InputSchema(type: "object", properties: [:], required: [])
            ),
            ToolDefinition(
                name: "book_flight",
                description: "Search for and book a flight by opening the booking app/website.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "origin": PropertyDefinition(type: "string", description: "Departure city or airport code (e.g. 'New York' or 'JFK')"),
                        "destination": PropertyDefinition(type: "string", description: "Arrival city or airport code (e.g. 'Los Angeles' or 'LAX')"),
                        "date": PropertyDefinition(type: "string", description: "Travel date in YYYY-MM-DD format"),
                        "passengers": PropertyDefinition(type: "string", description: "Number of passengers (default: 1)")
                    ],
                    required: ["origin", "destination", "date"]
                )
            ),
            ToolDefinition(
                name: "book_uber",
                description: "Book an Uber ride by opening the Uber app.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "pickup": PropertyDefinition(type: "string", description: "Pickup address or location name"),
                        "dropoff": PropertyDefinition(type: "string", description: "Drop-off address or destination name")
                    ],
                    required: ["pickup", "dropoff"]
                )
            ),
            ToolDefinition(
                name: "compose_email",
                description: "Open the email app to compose and send an email.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "to": PropertyDefinition(type: "string", description: "Recipient email address"),
                        "subject": PropertyDefinition(type: "string", description: "Email subject line"),
                        "body": PropertyDefinition(type: "string", description: "Email body text")
                    ],
                    required: ["to", "subject", "body"]
                )
            ),
            ToolDefinition(
                name: "make_call",
                description: "Make a phone call. Provide contactName to look up the number from the user's Contacts, or phoneNumber if you already have it.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "contactName": PropertyDefinition(type: "string", description: "Name of the person to call — used to search the user's Contacts for their number"),
                        "phoneNumber": PropertyDefinition(type: "string", description: "Phone number to dial directly (digits only). Optional if contactName is provided.")
                    ],
                    required: []
                )
            ),
            ToolDefinition(
                name: "read_news",
                description: "Fetch the latest top news headlines from BBC News.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "topic": PropertyDefinition(type: "string", description: "Optional topic filter (e.g. 'technology', 'sports'). Leave empty for top stories.")
                    ],
                    required: []
                )
            ),
            ToolDefinition(
                name: "create_calendar_event",
                description: "Create a calendar event in the user's default iOS calendar.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "title": PropertyDefinition(type: "string", description: "Event title"),
                        "startISO": PropertyDefinition(type: "string", description: "Start date/time in ISO 8601 format (e.g. '2026-04-20T15:00:00Z'). Use get_datetime first to resolve relative times."),
                        "durationMinutes": PropertyDefinition(type: "string", description: "Event duration in minutes (default: 60)"),
                        "notes": PropertyDefinition(type: "string", description: "Optional event notes or description")
                    ],
                    required: ["title", "startISO"]
                )
            ),
            ToolDefinition(
                name: "get_calendar_events",
                description: "Read upcoming events from the user's iOS Calendar, including Zoom, Google Meet, and Microsoft Teams meeting links extracted from event URLs and notes.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "daysAhead": PropertyDefinition(type: "string", description: "How many days ahead to look for events (default: 7, max: 30)")
                    ],
                    required: []
                )
            ),
            ToolDefinition(
                name: "recall_places",
                description: "Retrieve the chronological log of places the user has navigated to, including who they met and any context (e.g. 'dinner', 'job interview'). Use when the user asks about past trips, visits, or who they met somewhere.",
                inputSchema: InputSchema(type: "object", properties: [:], required: [])
            ),
            ToolDefinition(
                name: "get_directions",
                description: "Open Apple Maps with directions to a destination. Also auto-saves the visit to the user's place memory.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "destination": PropertyDefinition(type: "string", description: "Destination address, place name, or search query (e.g. 'nearest café', 'Heathrow Airport', '10 Downing Street')"),
                        "person":      PropertyDefinition(type: "string", description: "Optional — the person the user is meeting at this destination"),
                        "note":        PropertyDefinition(type: "string", description: "Optional — reason or context for the visit (e.g. 'dinner', 'job interview', 'gym')")
                    ],
                    required: ["destination"]
                )
            )
        ]
        let v1Names: Set<String> = ["get_datetime", "save_note", "get_notes", "delete_note", "remember_fact", "recall_facts", "schedule_reminder", "get_reminders", "get_calendar_events", "recall_places"]
        let extras = [
            ToolDefinition(name: "save_place", description: "Manually save a named place and full address. Never infer that the user visited it.", inputSchema: InputSchema(type: "object", properties: ["name": PropertyDefinition(type: "string", description: "Unique place name"), "address": PropertyDefinition(type: "string", description: "Street, city, country")], required: ["name", "address"])),
            ToolDefinition(name: "schedule_location_reminder", description: "Schedule one arrival reminder for an explicitly saved place.", inputSchema: InputSchema(type: "object", properties: ["title": PropertyDefinition(type: "string", description: "Reminder"), "placeName": PropertyDefinition(type: "string", description: "Exact saved place name")], required: ["title", "placeName"])),
            ToolDefinition(name: "schedule_context_reminder", description: "Save a reminder shown when the user explicitly checks the named context in Max. No background behavior monitoring.", inputSchema: InputSchema(type: "object", properties: ["title": PropertyDefinition(type: "string", description: "Reminder"), "context": PropertyDefinition(type: "string", description: "User supplied context name")], required: ["title", "context"])),
            ToolDefinition(name: "get_weather", description: "Get Apple Weather for a saved place. If no place name is supplied, use the most recently saved place with coordinates.", inputSchema: InputSchema(type: "object", properties: ["placeName": PropertyDefinition(type: "string", description: "Saved place name")], required: []))
        ]
        return definitions.filter { v1Names.contains($0.name) } + extras
    }

    // MARK: - Streaming API

    func streamMessage(
        messages: [Message],
        imageData: Data? = nil,     // JPEG/PNG data to send alongside the last user message
        onChunk: @escaping @Sendable (StreamChunk) -> Void
    ) -> Task<Void, Never> {
        Task {
            do {
                guard let base = URL(string: kMaxAPIBaseURL), base.scheme == "https", base.host != nil else { throw ClaudeError.noAPIKey }
                let session: (token: String, userID: String)
                do { session = try await AuthService.shared.managedSession() }
                catch { throw ClaudeError.signInRequired }
                try await streamMessageInternal(
                    sessionToken: session.token,
                    accountScope: session.userID,
                    messages: messages,
                    imageData: imageData,
                    conversationHistory: [],
                    round: 0,
                    onChunk: onChunk
                )
            } catch {
                if !Task.isCancelled { onChunk(.error(error.localizedDescription)) }
            }
        }
    }

    // Internal recursive method for tool-use agentic loop
    private func streamMessageInternal(
        sessionToken: String,
        accountScope: String,
        messages: [Message],
        imageData: Data? = nil,
        conversationHistory: [ClaudeRequestMessage],
        round: Int,
        onChunk: @escaping @Sendable (StreamChunk) -> Void
    ) async throws {

        try Task.checkCancellation()
        guard StorageService.shared.accountScope == accountScope else { throw ClaudeError.signInRequired }
        guard round < 6 else { throw ClaudeError.tooManyActions }
        // Build messages array for API
        var apiMessages: [ClaudeRequestMessage] = []

        // Convert app messages to API format
        for (index, msg) in messages.enumerated() {
            // Attach image to the last user message if provided
            let isLastUserMsg = msg.role == "user" && index == messages.indices.last(where: { messages[$0].role == "user" })
            if isLastUserMsg, let data = imageData {
                let b64 = data.base64EncodedString()
                // Detect JPEG vs PNG by magic bytes
                let mime = data.prefix(4).elementsEqual([0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"
                var parts: [ClaudeContentPart] = [.image(base64: b64, mediaType: mime)]
                if !msg.content.isEmpty {
                    parts.append(.text(msg.content))
                }
                apiMessages.append(ClaudeRequestMessag…12096 tokens truncated…t
                        self.messages[idx].isStreaming = true
                    }
                case .toolStart(let name):
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[idx].content = fullText + (fullText.isEmpty ? "" : "\n") + "_Using \(name)…_"
                        self.messages[idx].isStreaming = true
                    }
                case .toolDone:
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[idx].content = fullText
                    }
                case .done:
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[idx].content = fullText
                        self.messages[idx].isStreaming = false
                    }
                    self.streamingMessageId = nil
                    self.streamingText = ""
                    self.storage.saveMessages(self.messages)
                    self.archiveCurrentConversation()
                    self.pushToWidget(fullText)
                    if settings.voiceEnabled && !fullText.isEmpty {
                        self.conversationState = .speaking
                        self.voice.speak(fullText, preferredVoice: settings.preferredVoice)
                        Task {
                            while self.voice.isSpeaking {
                                try? await Task.sleep(nanoseconds: 200_000_000)
                            }
                            guard self.turnID == thisTurn else { return }
                            self.conversationState = .idle
                            if self.continuousActive, UIApplication.shared.applicationState == .active { self.startListening() }
                        }
                    } else {
                        self.conversationState = .idle
                    }
                case .error(let errText):
                    self.continuousActive = false
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        if fullText.isEmpty { self.messages[idx].content = "Error: \(errText)" }
                        self.messages[idx].isStreaming = false
                    }
                    self.streamingMessageId = nil
                    self.streamingText = ""
                    self.conversationState = .idle
                    self.storage.saveMessages(self.messages)
                }
            }
        }
    }
}

#Preview {
    HomeView().environmentObject(AuthService.shared)
}

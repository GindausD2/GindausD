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
    let system: String
    let messages: [ClaudeRequestMessage]
    let tools: [ToolDefinition]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case stream, system, messages, tools
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

    enum CodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case content, id, name, input
    }

    init(type: String, toolUseId: String? = nil, content: String? = nil,
         id: String? = nil, name: String? = nil, input: [String: AnyCodable]? = nil) {
        self.type = type
        self.toolUseId = toolUseId
        self.content = content
        self.id = id
        self.name = name
        self.input = input
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

    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"
    private let modelID = "claude-sonnet-4-6"
    private let maxTokens = 4096

    private init() {}

    // MARK: - Tools Definition

    private var toolDefinitions: [ToolDefinition] {
        [
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
                        "minutesFromNow": PropertyDefinition(type: "string", description: "Minutes from now to fire the reminder")
                    ],
                    required: ["title", "body", "minutesFromNow"]
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
                description: "Make a phone call to a contact or phone number.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "phoneNumber": PropertyDefinition(type: "string", description: "Phone number to call (digits only, e.g. '14155552671')"),
                        "contactName": PropertyDefinition(type: "string", description: "Name of the person being called")
                    ],
                    required: ["phoneNumber"]
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
    }

    // MARK: - Streaming API

    func streamMessage(
        apiKey: String,
        messages: [Message],
        imageData: Data? = nil,     // JPEG/PNG data to send alongside the last user message
        onChunk: @escaping @Sendable (StreamChunk) -> Void
    ) {
        Task {
            do {
                try await streamMessageInternal(
                    apiKey: apiKey,
                    messages: messages,
                    imageData: imageData,
                    conversationHistory: [],
                    onChunk: onChunk
                )
            } catch {
                onChunk(.error(error.localizedDescription))
            }
        }
    }

    // Internal recursive method for tool-use agentic loop
    private func streamMessageInternal(
        apiKey: String,
        messages: [Message],
        imageData: Data? = nil,
        conversationHistory: [[String: Any]],
        onChunk: @escaping @Sendable (StreamChunk) -> Void
    ) async throws {

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
                apiMessages.append(ClaudeRequestMessage(role: msg.role, content: .parts(parts)))
            } else {
                apiMessages.append(ClaudeRequestMessage(role: msg.role, content: .string(msg.content)))
            }
        }

        let request = ClaudeRequest(
            model: modelID,
            maxTokens: maxTokens,
            stream: true,
            system: systemPrompt,
            messages: apiMessages,
            tools: toolDefinitions
        )

        var urlRequest = URLRequest(url: apiURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to read error body
            var errorBody = ""
            for try await byte in asyncBytes {
                errorBody.append(Character(UnicodeScalar(byte)))
                if errorBody.count > 500 { break }
            }
            throw ClaudeError.apiError(httpResponse.statusCode, errorBody)
        }

        // SSE parsing state
        var currentEvent: String? = nil
        var currentData: String? = nil
        var lineBuffer = ""

        // Accumulated tool calls
        var pendingToolCalls: [AccumulatedToolCall] = []
        var currentToolCallIndex: Int? = nil
        var stopReason: String? = nil

        // Accumulated text for building final message
        var accumulatedText = ""

        for try await byte in asyncBytes {
            let char = Character(UnicodeScalar(byte))

            if char == "\n" {
                let line = lineBuffer
                lineBuffer = ""

                if line.isEmpty {
                    // Empty line = dispatch event
                    if let data = currentData, !data.isEmpty {
                        let event = SSEEvent(event: currentEvent, data: data)
                        let shouldStop = try await processSSEEvent(
                            event: event,
                            pendingToolCalls: &pendingToolCalls,
                            currentToolCallIndex: &currentToolCallIndex,
                            stopReason: &stopReason,
                            accumulatedText: &accumulatedText,
                            onChunk: onChunk
                        )
                        if shouldStop { break }
                    }
                    currentEvent = nil
                    currentData = nil
                } else if line.hasPrefix("event: ") {
                    currentEvent = String(line.dropFirst(7))
                } else if line.hasPrefix("data: ") {
                    currentData = String(line.dropFirst(6))
                }
            } else if char != "\r" {
                lineBuffer.append(char)
            }
        }

        // Handle any pending tool calls
        if stopReason == "tool_use" && !pendingToolCalls.isEmpty {
            onChunk(.toolDone)
            try await executeToolsAndContinue(
                apiKey: apiKey,
                messages: messages,
                accumulatedText: accumulatedText,
                pendingToolCalls: pendingToolCalls,
                onChunk: onChunk
            )
        } else {
            onChunk(.done)
        }
    }

    private func processSSEEvent(
        event: SSEEvent,
        pendingToolCalls: inout [AccumulatedToolCall],
        currentToolCallIndex: inout Int?,
        stopReason: inout String?,
        accumulatedText: inout String,
        onChunk: @escaping @Sendable (StreamChunk) -> Void
    ) async throws -> Bool {

        guard let data = event.data, data != "[DONE]" else {
            return data == "[DONE]"
        }

        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return false }

        let eventType = event.event ?? (json["type"] as? String ?? "")

        switch eventType {
        case "content_block_start":
            if let contentBlock = json["content_block"] as? [String: Any] {
                let blockType = contentBlock["type"] as? String ?? ""
                let index = json["index"] as? Int ?? 0

                if blockType == "tool_use" {
                    let toolName = contentBlock["name"] as? String ?? ""
                    let toolId = contentBlock["id"] as? String ?? UUID().uuidString
                    let toolCall = AccumulatedToolCall(id: toolId, name: toolName)
                    pendingToolCalls.append(toolCall)
                    currentToolCallIndex = index
                    onChunk(.toolStart(toolName))
                }
            }

        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any] {
                let deltaType = delta["type"] as? String ?? ""

                if deltaType == "text_delta" {
                    let text = delta["text"] as? String ?? ""
                    accumulatedText += text
                    onChunk(.text(text))
                } else if deltaType == "input_json_delta" {
                    let partialJSON = delta["partial_json"] as? String ?? ""
                    // Append to the last tool call's input
                    if !pendingToolCalls.isEmpty {
                        pendingToolCalls[pendingToolCalls.count - 1].inputJSON += partialJSON
                    }
                }
            }

        case "message_delta":
            if let delta = json["delta"] as? [String: Any] {
                stopReason = delta["stop_reason"] as? String
            }

        case "message_stop":
            return true

        default:
            break
        }

        return false
    }

    private func executeToolsAndContinue(
        apiKey: String,
        messages: [Message],
        accumulatedText: String,
        pendingToolCalls: [AccumulatedToolCall],
        onChunk: @escaping @Sendable (StreamChunk) -> Void
    ) async throws {

        // Execute all tools
        var toolResults: [(id: String, result: String)] = []

        for toolCall in pendingToolCalls {
            // Parse input JSON
            var inputDict: [String: Any] = [:]
            if let inputData = toolCall.inputJSON.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] {
                inputDict = parsed
            }

            let result = await ToolsService.shared.execute(name: toolCall.name, input: inputDict)
            toolResults.append((id: toolCall.id, result: result))
        }

        // Build updated messages including assistant turn + tool results
        var updatedMessages = messages

        // Add the assistant message with tool_use blocks
        // We append a synthetic assistant message
        var toolResultsBlocks: [[String: Any]] = []
        for result in toolResults {
            toolResultsBlocks.append([
                "type": "tool_result",
                "tool_use_id": result.id,
                "content": result.result
            ])
        }

        // Create continuation messages with tool results
        // Build an updated message list including tool use and results
        // We'll create new Message objects representing this exchange
        var continuationMessages = updatedMessages

        // Add assistant message (text + tool calls) as a combined message
        // For simplicity, we rebuild as a new assistant message noting tool use happened
        // The proper way: we need raw API messages — handled via a different path

        // Simplified approach: add a continuation message that includes tool results
        // and re-invoke the API with the full context
        let toolSummary = toolResults.map { "Tool \($0.id): \($0.result)" }.joined(separator: "\n")

        // Create synthetic messages that include tool context
        // Assistant turn describing what tool was called
        let assistantTurn = Message(
            role: "assistant",
            content: accumulatedText.isEmpty
                ? "[Tool execution: \(pendingToolCalls.map { $0.name }.joined(separator: ", "))]"
                : accumulatedText
        )
        continuationMessages.append(assistantTurn)

        // User turn with tool results
        let toolResultMessage = Message(
            role: "user",
            content: "Tool results:\n\(toolSummary)\n\nPlease continue based on these results."
        )
        continuationMessages.append(toolResultMessage)

        // Continue streaming with updated context (image not re-sent on continuation)
        try await streamMessageInternal(
            apiKey: apiKey,
            messages: continuationMessages,
            imageData: nil,
            conversationHistory: [],
            onChunk: onChunk
        )
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case invalidResponse
    case apiError(Int, String)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let code, let body):
            return "API error \(code): \(body)"
        case .noAPIKey:
            return "No API key configured. Please add your API key in Settings."
        }
    }
}

package com.max.ai.services

import com.max.ai.ClaudeMessage
import com.max.ai.ToolDefinition
import com.max.ai.ToolInputSchema
import com.max.ai.ToolProperty
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.serialization.json.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

// ─── Stream result types ──────────────────────────────────────────────────────

sealed class StreamChunk {
    data class Text(val delta: String) : StreamChunk()
    data class ToolStart(val name: String, val toolUseId: String) : StreamChunk()
    data class ToolInput(val partial: String) : StreamChunk()
    object ToolDone : StreamChunk()
    object Done : StreamChunk()
    data class Error(val message: String) : StreamChunk()
}

// ─── ClaudeService ────────────────────────────────────────────────────────────

class ClaudeService {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    // Default tools exposed to Claude
    private val availableTools: List<ToolDefinition> = listOf(
        ToolDefinition(
            name = "get_datetime",
            description = "Get the current date and time",
            input_schema = ToolInputSchema(properties = emptyMap(), required = emptyList())
        ),
        ToolDefinition(
            name = "save_note",
            description = "Save a note with a title and content",
            input_schema = ToolInputSchema(
                properties = mapOf(
                    "title" to ToolProperty("string", "The note title"),
                    "content" to ToolProperty("string", "The note content")
                ),
                required = listOf("title", "content")
            )
        ),
        ToolDefinition(
            name = "get_notes",
            description = "Retrieve all saved notes",
            input_schema = ToolInputSchema(properties = emptyMap(), required = emptyList())
        ),
        ToolDefinition(
            name = "delete_note",
            description = "Delete a note by its ID",
            input_schema = ToolInputSchema(
                properties = mapOf(
                    "id" to ToolProperty("string", "The note ID to delete")
                ),
                required = listOf("id")
            )
        ),
        ToolDefinition(
            name = "remember_fact",
            description = "Remember a fact about the user",
            input_schema = ToolInputSchema(
                properties = mapOf(
                    "key" to ToolProperty("string", "Fact key/category"),
                    "value" to ToolProperty("string", "The fact to remember")
                ),
                required = listOf("key", "value")
            )
        ),
        ToolDefinition(
            name = "recall_facts",
            description = "Recall all remembered facts about the user",
            input_schema = ToolInputSchema(properties = emptyMap(), required = emptyList())
        ),
        ToolDefinition(
            name = "schedule_reminder",
            description = "Schedule a reminder at a specific time",
            input_schema = ToolInputSchema(
                properties = mapOf(
                    "title" to ToolProperty("string", "Reminder text"),
                    "trigger_at_millis" to ToolProperty("string", "Unix timestamp in milliseconds for when to trigger")
                ),
                required = listOf("title", "trigger_at_millis")
            )
        ),
        ToolDefinition(
            name = "get_reminders",
            description = "Get all upcoming scheduled reminders",
            input_schema = ToolInputSchema(properties = emptyMap(), required = emptyList())
        ),
        ToolDefinition(
            name = "book_flight",
            description = "Search and book a flight by opening Kayak with pre-filled search",
            input_schema = ToolInputSchema(
                properties = mapOf(
                    "origin" to ToolProperty("string", "Departure city or airport code (e.g. 'New York' or 'JFK')"),
                    "destination" to ToolProperty("string", "Arrival city or airport code (e.g. 'Los Angeles' or 'LAX')"),
                    "date" to ToolProperty("string", "Travel date in YYYY-MM-DD format"),
                    "passengers" to ToolProperty("string", "Number of passengers (default: 1)")
                ),
                required = listOf("origin", "destination", "date")
            )
        ),
        ToolDefinition(
            name = "book_uber",
            description = "Book an Uber ride by opening the Uber app with pickup and dropoff pre-filled",
            input_schema = ToolInputSchema(
                properties = mapOf(
                    "pickup" to ToolProperty("string", "Pickup address or location name"),
                    "dropoff" to ToolProperty("string", "Drop-off address or destination name")
                ),
                required = listOf("pickup", "dropoff")
            )
        ),
        ToolDefinition(
            name = "compose_email",
            description = "Open the email app to compose and send an email",
            input_schema = ToolInputSchema(
                properties = mapOf(
                    "to" to ToolProperty("string", "Recipient email address"),
                    "subject" to ToolProperty("string", "Email subject line"),
                    "body" to ToolProperty("string", "Email body text")
                ),
                required = listOf("to", "subject", "body")
            )
        ),
        ToolDefinition(
            name = "make_call",
            description = "Make a phone call by opening the dialer with the number pre-filled",
            input_schema = ToolInputSchema(
                properties = mapOf(
                    "phoneNumber" to ToolProperty("string", "Phone number to call (digits only, e.g. '14155552671')"),
                    "contactName" to ToolProperty("string", "Name of the person being called")
                ),
                required = listOf("phoneNumber")
            )
        )
    )

    /**
     * Stream a response from Claude. Handles the agentic loop internally:
     * if Claude requests a tool call, [onToolCall] is invoked to get the result,
     * then the conversation continues automatically.
     *
     * @param apiKey       Anthropic API key
     * @param messages     Current conversation history
     * @param systemPrompt System prompt
     * @param onToolCall   Suspend callback: (toolName, toolUseId, inputJson) -> result string
     */
    fun streamResponse(
        apiKey: String,
        messages: List<ClaudeMessage>,
        systemPrompt: String = DEFAULT_SYSTEM_PROMPT,
        imageBytes: ByteArray? = null,
        onToolCall: suspend (name: String, toolUseId: String, input: Map<String, JsonElement>) -> String
    ): Flow<StreamChunk> = callbackFlow {
        var conversationMessages = messages.toMutableList()
        var continueLoop = true
        var isFirstCall = true

        while (continueLoop) {
            continueLoop = false

            val requestBody = buildRequestBody(
                conversationMessages,
                systemPrompt,
                if (isFirstCall) imageBytes else null
            )
            isFirstCall = false
            val request = Request.Builder()
                .url(CLAUDE_API_URL)
                .post(requestBody.toRequestBody(JSON_MEDIA_TYPE))
                .header("x-api-key", apiKey)
                .header("anthropic-version", "2023-06-01")
                .header("content-type", "application/json")
                .header("accept", "text/event-stream")
                .build()

            var currentToolUseId = ""
            var currentToolName = ""
            var currentBlockIsToolUse = false
            val toolInputBuilder = StringBuilder()
            val pendingToolCalls = mutableListOf<Triple<String, String, String>>() // id, name, input

            var call: Call? = null
            try {
                call = client.newCall(request)
                val response = call.execute()

                if (!response.isSuccessful) {
                    val errorBody = response.body?.string() ?: "Unknown error"
                    trySend(StreamChunk.Error("HTTP ${response.code}: $errorBody"))
                    close()
                    return@callbackFlow
                }

                val body = response.body ?: run {
                    trySend(StreamChunk.Error("Empty response body"))
                    close()
                    return@callbackFlow
                }

                var stopReason: String? = null

                BufferedReader(InputStreamReader(body.byteStream())).use { reader ->
                    var line: String?
                    var eventType = ""
                    val dataBuffer = StringBuilder()

                    while (reader.readLine().also { line = it } != null) {
                        val trimmed = line!!.trim()

                        when {
                            trimmed.startsWith("event:") -> {
                                eventType = trimmed.removePrefix("event:").trim()
                            }
                            trimmed.startsWith("data:") -> {
                                dataBuffer.append(trimmed.removePrefix("data:").trim())
                            }
                            trimmed.isEmpty() && dataBuffer.isNotEmpty() -> {
                                // Process accumulated event
                                val data = dataBuffer.toString()
                                dataBuffer.clear()

                                processSSEEvent(
                                    eventType = eventType,
                                    data = data,
                                    onText = { delta -> trySend(StreamChunk.Text(delta)) },
                                    onToolStart = { id, name ->
                                        currentToolUseId = id
                                        currentToolName = name
                                        currentBlockIsToolUse = true
                                        toolInputBuilder.clear()
                                        trySend(StreamChunk.ToolStart(name, id))
                                    },
                                    onNonToolBlockStart = {
                                        currentBlockIsToolUse = false
                                    },
                                    onToolInputDelta = { partial ->
                                        toolInputBuilder.append(partial)
                                        trySend(StreamChunk.ToolInput(partial))
                                    },
                                    onBlockStop = {
                                        if (currentBlockIsToolUse) {
                                            pendingToolCalls.add(
                                                Triple(currentToolUseId, currentToolName, toolInputBuilder.toString())
                                            )
                                            trySend(StreamChunk.ToolDone)
                                            toolInputBuilder.clear()
                                            currentBlockIsToolUse = false
                                        }
                                    },
                                    onStopReason = { reason -> stopReason = reason }
                                )
                                eventType = ""
                            }
                        }
                    }
                }

                // If tools were called, execute them and loop
                if (pendingToolCalls.isNotEmpty() && stopReason == "tool_use") {
                    // Build assistant message with tool_use blocks
                    val assistantContent = buildAssistantToolUseContent(pendingToolCalls)
                    conversationMessages.add(
                        ClaudeMessage(role = "assistant", content = assistantContent)
                    )

                    // Execute each tool and collect results
                    val toolResults = pendingToolCalls.map { (id, name, inputJson) ->
                        val inputMap = runCatching {
                            json.parseToJsonElement(inputJson.ifBlank { "{}" })
                                .jsonObject
                                .toMap()
                        }.getOrElse { emptyMap() }

                        val result = runCatching {
                            onToolCall(name, id, inputMap)
                        }.getOrElse { e -> "Error: ${e.message}" }

                        Triple(id, name, result)
                    }

                    // Build tool_result user message
                    val toolResultContent = buildToolResultContent(toolResults)
                    conversationMessages.add(
                        ClaudeMessage(role = "user", content = toolResultContent)
                    )

                    continueLoop = true // continue the agentic loop
                } else {
                    trySend(StreamChunk.Done)
                }

            } catch (e: IOException) {
                trySend(StreamChunk.Error("Network error: ${e.message}"))
            } catch (e: Exception) {
                trySend(StreamChunk.Error("Error: ${e.message}"))
            } finally {
                call?.cancel()
            }
        }

        close()
        awaitClose { }
    }.flowOn(Dispatchers.IO)

    // ─── SSE parsing ──────────────────────────────────────────────────────────

    private fun processSSEEvent(
        eventType: String,
        data: String,
        onText: (String) -> Unit,
        onToolStart: (id: String, name: String) -> Unit,
        onNonToolBlockStart: () -> Unit,
        onToolInputDelta: (String) -> Unit,
        onBlockStop: () -> Unit,
        onStopReason: (String) -> Unit
    ) {
        if (data == "[DONE]") return

        runCatching {
            val element = Json.parseToJsonElement(data).jsonObject
            val type = element["type"]?.jsonPrimitive?.content ?: return

            when (type) {
                "content_block_start" -> {
                    val block = element["content_block"]?.jsonObject ?: return
                    val blockType = block["type"]?.jsonPrimitive?.content ?: return
                    if (blockType == "tool_use") {
                        val id = block["id"]?.jsonPrimitive?.content ?: ""
                        val name = block["name"]?.jsonPrimitive?.content ?: ""
                        onToolStart(id, name)
                    } else {
                        onNonToolBlockStart()
                    }
                }
                "content_block_delta" -> {
                    val delta = element["delta"]?.jsonObject ?: return
                    val deltaType = delta["type"]?.jsonPrimitive?.content ?: return
                    when (deltaType) {
                        "text_delta" -> {
                            val text = delta["text"]?.jsonPrimitive?.content ?: ""
                            if (text.isNotEmpty()) onText(text)
                        }
                        "input_json_delta" -> {
                            val partial = delta["partial_json"]?.jsonPrimitive?.content ?: ""
                            onToolInputDelta(partial)
                        }
                    }
                }
                "content_block_stop" -> {
                    onBlockStop()
                }
                "message_delta" -> {
                    val delta = element["delta"]?.jsonObject ?: return
                    val stopReason = delta["stop_reason"]?.jsonPrimitive?.content ?: return
                    onStopReason(stopReason)
                }
            }
        }
    }

    // ─── Request body builder ─────────────────────────────────────────────────

    private fun buildRequestBody(messages: List<ClaudeMessage>, systemPrompt: String, imageBytes: ByteArray? = null): String {
        val toolsJson = availableTools.map { tool ->
            buildJsonObject {
                put("name", tool.name)
                put("description", tool.description)
                put("input_schema", buildJsonObject {
                    put("type", tool.input_schema.type)
                    put("properties", buildJsonObject {
                        tool.input_schema.properties.forEach { (k, v) ->
                            put(k, buildJsonObject {
                                put("type", v.type)
                                put("description", v.description)
                            })
                        }
                    })
                    put("required", buildJsonArray {
                        tool.input_schema.required.forEach { add(it) }
                    })
                })
            }
        }

        val lastUserIdx = if (imageBytes != null) messages.indexOfLast { it.role == "user" } else -1

        val messagesJson = messages.mapIndexed { index, msg ->
            buildJsonObject {
                put("role", msg.role)
                if (index == lastUserIdx && imageBytes != null) {
                    val b64 = android.util.Base64.encodeToString(imageBytes, android.util.Base64.NO_WRAP)
                    put("content", buildJsonArray {
                        add(buildJsonObject {
                            put("type", "image")
                            put("source", buildJsonObject {
                                put("type", "base64")
                                put("media_type", "image/jpeg")
                                put("data", b64)
                            })
                        })
                        if (msg.content.isNotEmpty()) {
                            add(buildJsonObject {
                                put("type", "text")
                                put("text", msg.content)
                            })
                        }
                    })
                } else {
                    val isJsonArray = msg.content.trimStart().startsWith("[")
                    if (isJsonArray) {
                        put("content", Json.parseToJsonElement(msg.content))
                    } else {
                        put("content", msg.content)
                    }
                }
            }
        }

        return buildJsonObject {
            put("model", MODEL)
            put("max_tokens", 4096)
            put("stream", true)
            put("system", systemPrompt)
            put("messages", buildJsonArray { messagesJson.forEach { add(it) } })
            put("tools", buildJsonArray { toolsJson.forEach { add(it) } })
        }.toString()
    }

    // ─── Content block builders for tool calls ────────────────────────────────

    private fun buildAssistantToolUseContent(
        toolCalls: List<Triple<String, String, String>>
    ): String {
        val array = buildJsonArray {
            toolCalls.forEach { (id, name, inputJson) ->
                add(buildJsonObject {
                    put("type", "tool_use")
                    put("id", id)
                    put("name", name)
                    put("input", runCatching {
                        Json.parseToJsonElement(inputJson.ifBlank { "{}" })
                    }.getOrElse { buildJsonObject { } })
                })
            }
        }
        return array.toString()
    }

    private fun buildToolResultContent(
        results: List<Triple<String, String, String>>
    ): String {
        val array = buildJsonArray {
            results.forEach { (id, _, result) ->
                add(buildJsonObject {
                    put("type", "tool_result")
                    put("tool_use_id", id)
                    put("content", result)
                })
            }
        }
        return array.toString()
    }

    companion object {
        private const val CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
        private const val MODEL = "claude-sonnet-4-6"
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

        const val DEFAULT_SYSTEM_PROMPT = """You are Max, a brilliant and warm AI personal assistant living inside the user's phone. You have access to tools that let you take real actions: saving notes, remembering facts, scheduling reminders, booking flights, calling an Uber, composing emails, making phone calls, and analysing photos.

Your personality:
- Warm, encouraging, and genuinely interested in helping
- Concise but thorough — get to the point without being curt
- Proactive: if you notice something worth remembering or scheduling, suggest it

Your capabilities:
- save_note / get_notes / delete_note: manage notes
- remember_fact / recall_facts: store and retrieve facts about the user
- get_datetime: get the current date and time
- schedule_reminder / get_reminders: set and list local reminders
- book_flight: open Kayak with flight search pre-filled
- book_uber: open the Uber app with pickup and dropoff pre-filled
- compose_email: open the email app with recipient, subject, and body pre-filled
- make_call: open the phone dialer with a number pre-filled

Guidelines:
- Use get_datetime before scheduling or booking with a relative date ("tomorrow")
- Confirm details before booking flights or rides if anything is ambiguous
- Write polished email bodies unless the user gives exact wording
- Respond conversationally — you live in their pocket, not in a report"""
    }
}

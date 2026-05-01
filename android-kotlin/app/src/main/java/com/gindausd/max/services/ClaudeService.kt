package com.gindausd.max.services

import com.gindausd.max.Config
import com.gindausd.max.Message
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

sealed class ClaudeChunk {
    data class Text(val text: String) : ClaudeChunk()
    data class ToolStart(val name: String) : ClaudeChunk()
    data class ToolDone(val name: String, val inputJson: String) : ClaudeChunk()
    object Done : ClaudeChunk()
    data class Error(val message: String) : ClaudeChunk()
}

class ClaudeService private constructor() {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val systemPrompt = """
You are Max, an intelligent AI personal assistant. You are helpful, friendly, and concise.
You have access to various tools to help users with their daily tasks.
When using tools, explain what you're doing in a natural, conversational way.
Keep responses concise and actionable. Use a warm, professional tone.
If you don't have enough information to use a tool, ask for clarification.
""".trimIndent()

    private val tools = buildToolDefinitions()

    suspend fun streamMessage(
        messages: List<Message>,
        imageData: ByteArray?,
        onChunk: (ClaudeChunk) -> Unit
    ) = withContext(Dispatchers.IO) {
        try {
            val messagesArray = JSONArray()
            for (msg in messages) {
                val msgObj = JSONObject()
                msgObj.put("role", msg.role)
                if (imageData != null && msg == messages.last() && msg.role == "user") {
                    val contentArray = JSONArray()
                    val imageObj = JSONObject()
                    imageObj.put("type", "image")
                    val sourceObj = JSONObject()
                    sourceObj.put("type", "base64")
                    sourceObj.put("media_type", "image/jpeg")
                    sourceObj.put("data", android.util.Base64.encodeToString(imageData, android.util.Base64.NO_WRAP))
                    imageObj.put("source", sourceObj)
                    contentArray.put(imageObj)
                    val textObj = JSONObject()
                    textObj.put("type", "text")
                    textObj.put("text", msg.content)
                    contentArray.put(textObj)
                    msgObj.put("content", contentArray)
                } else {
                    msgObj.put("content", msg.content)
                }
                messagesArray.put(msgObj)
            }

            val body = JSONObject().apply {
                put("model", Config.CLAUDE_MODEL)
                put("max_tokens", 1024)
                put("stream", true)
                put("system", systemPrompt)
                put("tools", tools)
                put("messages", messagesArray)
            }

            val request = Request.Builder()
                .url("https://api.anthropic.com/v1/messages")
                .addHeader("x-api-key", Config.ANTHROPIC_API_KEY)
                .addHeader("anthropic-version", "2023-06-01")
                .addHeader("content-type", "application/json")
                .post(body.toString().toRequestBody("application/json".toMediaType()))
                .build()

            val response = client.newCall(request).execute()
            if (!response.isSuccessful) {
                val errorBody = response.body?.string() ?: "Unknown error"
                onChunk(ClaudeChunk.Error("HTTP ${response.code}: $errorBody"))
                return@withContext
            }

            val source = response.body?.source() ?: run {
                onChunk(ClaudeChunk.Error("Empty response body"))
                return@withContext
            }

            var currentToolName: String? = null
            var toolInputBuffer = StringBuilder()
            var inToolInput = false

            while (!source.exhausted()) {
                val line = source.readUtf8Line() ?: break
                if (line.startsWith("data: ")) {
                    val data = line.removePrefix("data: ").trim()
                    if (data == "[DONE]") break
                    try {
                        val obj = JSONObject(data)
                        val type = obj.optString("type")
                        when (type) {
                            "content_block_start" -> {
                                val block = obj.optJSONObject("content_block")
                                if (block?.optString("type") == "tool_use") {
                                    currentToolName = block.optString("name")
                                    toolInputBuffer = StringBuilder()
                                    inToolInput = true
                                    onChunk(ClaudeChunk.ToolStart(currentToolName ?: ""))
                                }
                            }
                            "content_block_delta" -> {
                                val delta = obj.optJSONObject("delta")
                                when (delta?.optString("type")) {
                                    "text_delta" -> {
                                        val text = delta.optString("text")
                                        if (text.isNotEmpty()) {
                                            onChunk(ClaudeChunk.Text(text))
                                        }
                                    }
                                    "input_json_delta" -> {
                                        if (inToolInput) {
                                            toolInputBuffer.append(delta.optString("partial_json"))
                                        }
                                    }
                                }
                            }
                            "content_block_stop" -> {
                                if (inToolInput) {
                                    inToolInput = false
                                    onChunk(ClaudeChunk.ToolDone(
                                        name = currentToolName ?: "",
                                        inputJson = toolInputBuffer.toString()
                                    ))
                                    currentToolName = null
                                    toolInputBuffer = StringBuilder()
                                }
                            }
                            "message_stop" -> {
                                onChunk(ClaudeChunk.Done)
                                break
                            }
                            "error" -> {
                                val error = obj.optJSONObject("error")
                                onChunk(ClaudeChunk.Error(error?.optString("message") ?: "Stream error"))
                                break
                            }
                        }
                    } catch (e: Exception) {
                        // Skip malformed SSE lines
                    }
                }
            }
        } catch (e: Exception) {
            onChunk(ClaudeChunk.Error(e.message ?: "Unknown error"))
        }
    }

    private fun buildToolDefinitions(): JSONArray {
        val toolList = JSONArray()

        fun tool(name: String, description: String, properties: JSONObject, required: List<String> = emptyList()): JSONObject {
            return JSONObject().apply {
                put("name", name)
                put("description", description)
                put("input_schema", JSONObject().apply {
                    put("type", "object")
                    put("properties", properties)
                    if (required.isNotEmpty()) put("required", JSONArray(required))
                })
            }
        }

        fun stringProp(desc: String) = JSONObject().apply { put("type", "string"); put("description", desc) }
        fun intProp(desc: String) = JSONObject().apply { put("type", "integer"); put("description", desc) }

        toolList.put(tool("save_note",
            "Save a note for the user",
            JSONObject().apply {
                put("title", stringProp("Title of the note"))
                put("content", stringProp("Content of the note"))
            }, listOf("title", "content")))

        toolList.put(tool("get_notes",
            "Retrieve all saved notes",
            JSONObject()))

        toolList.put(tool("remember_fact",
            "Remember a fact about the user",
            JSONObject().apply {
                put("key", stringProp("The key/category for this fact"))
                put("value", stringProp("The value/detail to remember"))
            }, listOf("key", "value")))

        toolList.put(tool("recall_facts",
            "Recall all remembered facts about the user",
            JSONObject()))

        toolList.put(tool("get_datetime",
            "Get the current date and time",
            JSONObject()))

        toolList.put(tool("schedule_reminder",
            "Schedule a reminder notification",
            JSONObject().apply {
                put("title", stringProp("Title of the reminder"))
                put("body", stringProp("Body text of the reminder"))
                put("delay_minutes", intProp("Minutes from now to fire the reminder"))
            }, listOf("title", "body", "delay_minutes")))

        toolList.put(tool("book_flight",
            "Open flight booking for a destination",
            JSONObject().apply {
                put("destination", stringProp("Destination city or airport"))
                put("origin", stringProp("Origin city or airport (optional)"))
            }, listOf("destination")))

        toolList.put(tool("book_uber",
            "Open Uber app to book a ride",
            JSONObject().apply {
                put("destination", stringProp("Destination address"))
            }, listOf("destination")))

        toolList.put(tool("compose_email",
            "Open email composer",
            JSONObject().apply {
                put("to", stringProp("Recipient email address"))
                put("subject", stringProp("Email subject"))
                put("body", stringProp("Email body"))
            }, listOf("to")))

        toolList.put(tool("make_call",
            "Make a phone call",
            JSONObject().apply {
                put("phone_number", stringProp("Phone number to call"))
            }, listOf("phone_number")))

        toolList.put(tool("read_news",
            "Get top news headlines",
            JSONObject()))

        toolList.put(tool("create_calendar_event",
            "Create a calendar event",
            JSONObject().apply {
                put("title", stringProp("Event title"))
                put("start_time", stringProp("Start time in ISO 8601 format"))
                put("end_time", stringProp("End time in ISO 8601 format"))
                put("location", stringProp("Event location (optional)"))
                put("description", stringProp("Event description (optional)"))
            }, listOf("title", "start_time", "end_time")))

        toolList.put(tool("get_calendar_events",
            "Get upcoming calendar events",
            JSONObject().apply {
                put("days_ahead", intProp("Number of days ahead to fetch (default 7)"))
            }))

        toolList.put(tool("get_directions",
            "Get directions to a location",
            JSONObject().apply {
                put("destination", stringProp("Destination address or place name"))
                put("origin", stringProp("Starting location (optional, uses current location)"))
            }, listOf("destination")))

        toolList.put(tool("recall_places",
            "Recall places the user has mentioned",
            JSONObject()))

        return toolList
    }

    companion object {
        @Volatile private var INSTANCE: ClaudeService? = null
        fun getInstance(): ClaudeService =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: ClaudeService().also { INSTANCE = it }
            }
    }
}

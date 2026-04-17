package com.max.ai

import kotlinx.serialization.Serializable

// ─── Chat / messaging ────────────────────────────────────────────────────────

@Serializable
data class Message(
    val id: String,
    val role: String,           // "user" | "assistant"
    val content: String,
    val timestamp: Long,
    val isStreaming: Boolean = false
)

// ─── App settings ─────────────────────────────────────────────────────────────

@Serializable
data class AppSettings(
    val apiKey: String = "",
    val assistantName: String = "Max",
    val voiceEnabled: Boolean = false,
    val userName: String = "",
    val colorScheme: String = "system",   // "system" | "light" | "dark"
    val preferredVoice: String = "female" // "female" | "male"
)

// ─── Notes ────────────────────────────────────────────────────────────────────

@Serializable
data class Note(
    val id: String,
    val title: String,
    val content: String,
    val createdAt: Long,
    val updatedAt: Long
)

// ─── Memory ───────────────────────────────────────────────────────────────────

@Serializable
data class UserMemory(
    val key: String,
    val value: String,
    val updatedAt: Long
)

// ─── Reminder ─────────────────────────────────────────────────────────────────

@Serializable
data class Reminder(
    val id: String,
    val title: String,
    val triggerAtMillis: Long,
    val isRepeating: Boolean = false
)

// ─── Auth ─────────────────────────────────────────────────────────────────────

@Serializable
data class AuthUser(
    val name: String? = null,
    val email: String? = null,
    val isDemo: Boolean = false
)

// ─── Claude API DTOs ──────────────────────────────────────────────────────────

@Serializable
data class ClaudeMessage(
    val role: String,
    val content: String
)

@Serializable
data class ToolDefinition(
    val name: String,
    val description: String,
    val input_schema: ToolInputSchema
)

@Serializable
data class ToolInputSchema(
    val type: String = "object",
    val properties: Map<String, ToolProperty> = emptyMap(),
    val required: List<String> = emptyList()
)

@Serializable
data class ToolProperty(
    val type: String,
    val description: String
)

// ─── Orb states ───────────────────────────────────────────────────────────────

enum class OrbState {
    IDLE, LISTENING, THINKING, SPEAKING
}

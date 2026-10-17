package com.gindausd.max

import androidx.compose.ui.graphics.Color
import kotlinx.serialization.Serializable

@Serializable
data class Message(
    val id: String,
    val role: String, // "user" or "assistant"
    val content: String,
    val timestamp: Long = System.currentTimeMillis(),
    val isStreaming: Boolean = false
)

@Serializable
data class AuthUser(
    val name: String? = null,
    val email: String? = null,
    val isDemo: Boolean? = false
)

@Serializable
data class AppSettings(
    val assistantName: String = "Max",
    val voiceEnabled: Boolean = true,
    val userName: String = "",
    val preferredVoice: String = "female",
    val briefingEnabled: Boolean = false,
    val briefingHour: Int = 8,
    val briefingMinute: Int = 0
)

@Serializable
data class Conversation(
    val id: String,
    val title: String,
    val messages: List<Message>,
    val startedAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Serializable
data class Note(
    val id: String,
    val title: String,
    val content: String,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Serializable
data class UserMemory(
    val key: String,
    val value: String,
    val updatedAt: Long = System.currentTimeMillis()
)

@Serializable
data class Reminder(
    val id: String,
    val title: String,
    val body: String,
    val fireDate: Long,
    val createdAt: Long = System.currentTimeMillis()
)

enum class ConversationState {
    IDLE,
    LISTENING,
    THINKING,
    SPEAKING
}

enum class OrbState(
    val primaryColor: Color,
    val secondaryColor: Color,
    val glowColor: Color,
    val pulseSpeed: Float,
    val minScale: Float,
    val maxScale: Float
) {
    IDLE(
        primaryColor = Color(0xFF78B5CD),
        secondaryColor = Color(0xFFC2E7F4),
        glowColor = Color(0x4078B5CD),
        pulseSpeed = 3000f,
        minScale = 0.95f,
        maxScale = 1.05f
    ),
    LISTENING(
        primaryColor = Color(0xFF78B5CD),
        secondaryColor = Color(0xFFC2E7F4),
        glowColor = Color(0x4078B5CD),
        pulseSpeed = 800f,
        minScale = 0.90f,
        maxScale = 1.15f
    ),
    THINKING(
        primaryColor = Color(0xFF78B5CD),
        secondaryColor = Color(0xFFC2E7F4),
        glowColor = Color(0x4078B5CD),
        pulseSpeed = 1500f,
        minScale = 0.92f,
        maxScale = 1.08f
    ),
    SPEAKING(
        primaryColor = Color(0xFF78B5CD),
        secondaryColor = Color(0xFFC2E7F4),
        glowColor = Color(0x4078B5CD),
        pulseSpeed = 600f,
        minScale = 0.88f,
        maxScale = 1.18f
    )
}

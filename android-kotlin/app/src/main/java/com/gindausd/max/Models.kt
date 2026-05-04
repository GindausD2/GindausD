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

@Serializable
enum class MemoryCategory {
    PERSONAL,
    PREFERENCES,
    WORK,
    HEALTH,
    OTHER;

    fun displayName(): String = when (this) {
        PERSONAL -> "Personal"
        PREFERENCES -> "Preferences"
        WORK -> "Work"
        HEALTH -> "Health"
        OTHER -> "Other"
    }
}

@Serializable
data class MemoryCard(
    val id: String,
    val category: MemoryCategory = MemoryCategory.OTHER,
    val key: String,
    val value: String,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
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
        primaryColor = Color(0xFFE87800),
        secondaryColor = Color(0xFFFF6600),
        glowColor = Color(0x40E87800),
        pulseSpeed = 3000f,
        minScale = 0.95f,
        maxScale = 1.05f
    ),
    LISTENING(
        primaryColor = Color(0xFFFF3B00),
        secondaryColor = Color(0xFFFF6030),
        glowColor = Color(0x60FF3B00),
        pulseSpeed = 800f,
        minScale = 0.90f,
        maxScale = 1.15f
    ),
    THINKING(
        primaryColor = Color(0xFFD97706),
        secondaryColor = Color(0xFFB45309),
        glowColor = Color(0x50D97706),
        pulseSpeed = 1500f,
        minScale = 0.92f,
        maxScale = 1.08f
    ),
    SPEAKING(
        primaryColor = Color(0xFFFF8C00),
        secondaryColor = Color(0xFFFF6000),
        glowColor = Color(0x55FF8C00),
        pulseSpeed = 600f,
        minScale = 0.88f,
        maxScale = 1.18f
    )
}

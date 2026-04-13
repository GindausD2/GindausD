package com.max.ai.services

import android.content.Context
import android.content.SharedPreferences
import com.max.ai.AppSettings
import com.max.ai.Message
import com.max.ai.Note
import com.max.ai.Reminder
import com.max.ai.UserMemory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class StorageRepository(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    // ─── Settings ─────────────────────────────────────────────────────────────

    private val _settingsFlow = MutableStateFlow(getSettings())
    val settingsFlow: StateFlow<AppSettings> = _settingsFlow.asStateFlow()

    fun getSettings(): AppSettings {
        val raw = prefs.getString(KEY_SETTINGS, null) ?: return AppSettings()
        return runCatching { json.decodeFromString<AppSettings>(raw) }.getOrElse { AppSettings() }
    }

    fun saveSettings(settings: AppSettings) {
        prefs.edit().putString(KEY_SETTINGS, json.encodeToString(settings)).apply()
        _settingsFlow.value = settings
    }

    fun updateApiKey(apiKey: String) {
        saveSettings(getSettings().copy(apiKey = apiKey))
    }

    fun updateUserName(name: String) {
        saveSettings(getSettings().copy(userName = name))
    }

    fun updateVoiceEnabled(enabled: Boolean) {
        saveSettings(getSettings().copy(voiceEnabled = enabled))
    }

    // ─── Messages ─────────────────────────────────────────────────────────────

    private val _messagesFlow = MutableStateFlow(getMessages())
    val messagesFlow: StateFlow<List<Message>> = _messagesFlow.asStateFlow()

    fun getMessages(): List<Message> {
        val raw = prefs.getString(KEY_MESSAGES, null) ?: return emptyList()
        return runCatching { json.decodeFromString<List<Message>>(raw) }.getOrElse { emptyList() }
    }

    fun saveMessages(messages: List<Message>) {
        prefs.edit().putString(KEY_MESSAGES, json.encodeToString(messages)).apply()
        _messagesFlow.value = messages
    }

    fun addMessage(message: Message) {
        val current = getMessages().toMutableList()
        current.add(message)
        saveMessages(current)
    }

    fun updateMessage(message: Message) {
        val current = getMessages().toMutableList()
        val idx = current.indexOfFirst { it.id == message.id }
        if (idx >= 0) current[idx] = message else current.add(message)
        saveMessages(current)
    }

    fun clearMessages() {
        saveMessages(emptyList())
    }

    // ─── Notes ────────────────────────────────────────────────────────────────

    fun getNotes(): List<Note> {
        val raw = prefs.getString(KEY_NOTES, null) ?: return emptyList()
        return runCatching { json.decodeFromString<List<Note>>(raw) }.getOrElse { emptyList() }
    }

    fun saveNote(note: Note) {
        val current = getNotes().toMutableList()
        val idx = current.indexOfFirst { it.id == note.id }
        if (idx >= 0) current[idx] = note else current.add(note)
        prefs.edit().putString(KEY_NOTES, json.encodeToString(current)).apply()
    }

    fun deleteNote(noteId: String) {
        val current = getNotes().filter { it.id != noteId }
        prefs.edit().putString(KEY_NOTES, json.encodeToString(current)).apply()
    }

    // ─── Memories ─────────────────────────────────────────────────────────────

    fun getMemories(): List<UserMemory> {
        val raw = prefs.getString(KEY_MEMORIES, null) ?: return emptyList()
        return runCatching { json.decodeFromString<List<UserMemory>>(raw) }.getOrElse { emptyList() }
    }

    fun saveMemory(memory: UserMemory) {
        val current = getMemories().toMutableList()
        val idx = current.indexOfFirst { it.key == memory.key }
        if (idx >= 0) current[idx] = memory else current.add(memory)
        prefs.edit().putString(KEY_MEMORIES, json.encodeToString(current)).apply()
    }

    fun getAllMemories(): List<UserMemory> = getMemories()

    // ─── Reminders ────────────────────────────────────────────────────────────

    fun getReminders(): List<Reminder> {
        val raw = prefs.getString(KEY_REMINDERS, null) ?: return emptyList()
        return runCatching { json.decodeFromString<List<Reminder>>(raw) }.getOrElse { emptyList() }
    }

    fun saveReminder(reminder: Reminder) {
        val current = getReminders().toMutableList()
        val idx = current.indexOfFirst { it.id == reminder.id }
        if (idx >= 0) current[idx] = reminder else current.add(reminder)
        prefs.edit().putString(KEY_REMINDERS, json.encodeToString(current)).apply()
    }

    fun deleteReminder(reminderId: String) {
        val current = getReminders().filter { it.id != reminderId }
        prefs.edit().putString(KEY_REMINDERS, json.encodeToString(current)).apply()
    }

    companion object {
        private const val PREFS_NAME = "max_ai_prefs"
        private const val KEY_SETTINGS = "max:settings"
        private const val KEY_MESSAGES = "max:messages"
        private const val KEY_NOTES = "max:notes"
        private const val KEY_MEMORIES = "max:memories"
        private const val KEY_REMINDERS = "max:reminders"
    }
}

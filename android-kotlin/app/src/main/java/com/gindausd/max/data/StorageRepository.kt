package com.gindausd.max.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.gindausd.max.AppSettings
import com.gindausd.max.Conversation
import com.gindausd.max.MemoryCard
import com.gindausd.max.Message
import com.gindausd.max.Note
import com.gindausd.max.Reminder
import com.gindausd.max.UserMemory
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "max_storage")

class StorageRepository private constructor(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private object Keys {
        val MESSAGES = stringPreferencesKey("messages")
        val SETTINGS = stringPreferencesKey("settings")
        val CONVERSATIONS = stringPreferencesKey("conversations")
        val NOTES = stringPreferencesKey("notes")
        val MEMORIES = stringPreferencesKey("memories")
        val MEMORY_CARDS = stringPreferencesKey("memory_cards")
        val REMINDERS = stringPreferencesKey("reminders")
        val PROFILE_PHOTO = stringPreferencesKey("profile_photo")
    }

    // Messages

    suspend fun saveMessages(messages: List<Message>) {
        context.dataStore.edit { prefs ->
            prefs[Keys.MESSAGES] = json.encodeToString(messages)
        }
    }

    suspend fun loadMessages(): List<Message> {
        val prefs = context.dataStore.data.firstOrNull() ?: return emptyList()
        val raw = prefs[Keys.MESSAGES] ?: return emptyList()
        return try {
            json.decodeFromString(raw)
        } catch (e: Exception) {
            emptyList()
        }
    }

    // Settings

    suspend fun saveSettings(settings: AppSettings) {
        context.dataStore.edit { prefs ->
            prefs[Keys.SETTINGS] = json.encodeToString(settings)
        }
    }

    suspend fun loadSettings(): AppSettings {
        val prefs = context.dataStore.data.firstOrNull() ?: return AppSettings()
        val raw = prefs[Keys.SETTINGS] ?: return AppSettings()
        return try {
            json.decodeFromString(raw)
        } catch (e: Exception) {
            AppSettings()
        }
    }

    // Conversations

    suspend fun saveConversation(conversation: Conversation) {
        val existing = loadConversations().toMutableList()
        val idx = existing.indexOfFirst { it.id == conversation.id }
        if (idx >= 0) existing[idx] = conversation else existing.add(0, conversation)
        context.dataStore.edit { prefs ->
            prefs[Keys.CONVERSATIONS] = json.encodeToString(existing)
        }
    }

    suspend fun loadConversations(): List<Conversation> {
        val prefs = context.dataStore.data.firstOrNull() ?: return emptyList()
        val raw = prefs[Keys.CONVERSATIONS] ?: return emptyList()
        return try {
            json.decodeFromString(raw)
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun deleteConversation(id: String) {
        val existing = loadConversations().filter { it.id != id }
        context.dataStore.edit { prefs ->
            prefs[Keys.CONVERSATIONS] = json.encodeToString(existing)
        }
    }

    // Notes

    suspend fun saveNote(note: Note) {
        val existing = loadNotes().toMutableList()
        val idx = existing.indexOfFirst { it.id == note.id }
        if (idx >= 0) existing[idx] = note else existing.add(0, note)
        context.dataStore.edit { prefs ->
            prefs[Keys.NOTES] = json.encodeToString(existing)
        }
    }

    suspend fun loadNotes(): List<Note> {
        val prefs = context.dataStore.data.firstOrNull() ?: return emptyList()
        val raw = prefs[Keys.NOTES] ?: return emptyList()
        return try {
            json.decodeFromString(raw)
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun deleteNote(id: String) {
        val existing = loadNotes().filter { it.id != id }
        context.dataStore.edit { prefs ->
            prefs[Keys.NOTES] = json.encodeToString(existing)
        }
    }

    // Memory (key-value facts)

    suspend fun rememberFact(key: String, value: String) {
        val existing = loadMemories().toMutableList()
        val idx = existing.indexOfFirst { it.key == key }
        val mem = UserMemory(key = key, value = value, updatedAt = System.currentTimeMillis())
        if (idx >= 0) existing[idx] = mem else existing.add(mem)
        context.dataStore.edit { prefs ->
            prefs[Keys.MEMORIES] = json.encodeToString(existing)
        }
    }

    suspend fun recallFacts(): List<UserMemory> = loadMemories()

    suspend fun deleteMemory(key: String) {
        val existing = loadMemories().filter { it.key != key }
        context.dataStore.edit { prefs ->
            prefs[Keys.MEMORIES] = json.encodeToString(existing)
        }
    }

    suspend fun clearMemories() {
        context.dataStore.edit { prefs ->
            prefs[Keys.MEMORIES] = json.encodeToString(emptyList<UserMemory>())
        }
    }

    private suspend fun loadMemories(): List<UserMemory> {
        val prefs = context.dataStore.data.firstOrNull() ?: return emptyList()
        val raw = prefs[Keys.MEMORIES] ?: return emptyList()
        return try {
            json.decodeFromString(raw)
        } catch (e: Exception) {
            emptyList()
        }
    }

    // Reminders

    suspend fun saveReminder(reminder: Reminder) {
        val existing = loadReminders().toMutableList()
        val idx = existing.indexOfFirst { it.id == reminder.id }
        if (idx >= 0) existing[idx] = reminder else existing.add(reminder)
        context.dataStore.edit { prefs ->
            prefs[Keys.REMINDERS] = json.encodeToString(existing)
        }
    }

    suspend fun loadReminders(): List<Reminder> {
        val prefs = context.dataStore.data.firstOrNull() ?: return emptyList()
        val raw = prefs[Keys.REMINDERS] ?: return emptyList()
        return try { json.decodeFromString(raw) } catch (e: Exception) { emptyList() }
    }

    suspend fun deleteReminder(id: String) {
        val existing = loadReminders().filter { it.id != id }
        context.dataStore.edit { prefs ->
            prefs[Keys.REMINDERS] = json.encodeToString(existing)
        }
    }

    // Memory cards

    suspend fun saveMemoryCard(card: MemoryCard) {
        val existing = loadMemoryCards().toMutableList()
        val idx = existing.indexOfFirst { it.id == card.id }
        if (idx >= 0) existing[idx] = card else existing.add(0, card)
        context.dataStore.edit { prefs ->
            prefs[Keys.MEMORY_CARDS] = json.encodeToString(existing)
        }
    }

    suspend fun loadMemoryCards(): List<MemoryCard> {
        val prefs = context.dataStore.data.firstOrNull() ?: return emptyList()
        val raw = prefs[Keys.MEMORY_CARDS] ?: return emptyList()
        return try {
            json.decodeFromString(raw)
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun deleteMemoryCard(id: String) {
        val existing = loadMemoryCards().filter { it.id != id }
        context.dataStore.edit { prefs ->
            prefs[Keys.MEMORY_CARDS] = json.encodeToString(existing)
        }
    }

    suspend fun clearMemoryCards() {
        context.dataStore.edit { prefs ->
            prefs[Keys.MEMORY_CARDS] = json.encodeToString(emptyList<MemoryCard>())
        }
    }

    // Profile photo (Base64 encoded)

    suspend fun saveProfilePhoto(base64: String) {
        context.dataStore.edit { prefs ->
            prefs[Keys.PROFILE_PHOTO] = base64
        }
    }

    suspend fun loadProfilePhoto(): String? {
        val prefs = context.dataStore.data.firstOrNull() ?: return null
        return prefs[Keys.PROFILE_PHOTO]
    }

    companion object {
        @Volatile private var INSTANCE: StorageRepository? = null
        fun getInstance(context: Context): StorageRepository =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: StorageRepository(context.applicationContext).also { INSTANCE = it }
            }
    }
}

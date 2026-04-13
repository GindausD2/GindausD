package com.max.ai.services

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.max.ai.Note
import com.max.ai.Reminder
import com.max.ai.UserMemory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonPrimitive
import java.text.SimpleDateFormat
import java.util.*

class ToolsService(
    private val context: Context,
    private val storageRepository: StorageRepository
) {

    suspend fun execute(
        name: String,
        input: Map<String, JsonElement>
    ): String = withContext(Dispatchers.IO) {
        try {
            when (name) {
                "get_datetime" -> getDatetime()
                "save_note" -> saveNote(input)
                "get_notes" -> getNotes()
                "delete_note" -> deleteNote(input)
                "remember_fact" -> rememberFact(input)
                "recall_facts" -> recallFacts()
                "schedule_reminder" -> scheduleReminder(input)
                else -> """{"error": "Unknown tool: $name"}"""
            }
        } catch (e: Exception) {
            Log.e(TAG, "Tool execution failed: $name", e)
            """{"error": "${e.message}"}"""
        }
    }

    // ─── Tool implementations ─────────────────────────────────────────────────

    private fun getDatetime(): String {
        val now = Date()
        val dateFormat = SimpleDateFormat("EEEE, MMMM d, yyyy", Locale.US)
        val timeFormat = SimpleDateFormat("h:mm a z", Locale.US)
        return """{"date": "${dateFormat.format(now)}", "time": "${timeFormat.format(now)}", "timestamp": ${now.time}}"""
    }

    private fun saveNote(input: Map<String, JsonElement>): String {
        val title = input["title"]?.jsonPrimitive?.content ?: return """{"error": "Missing title"}"""
        val content = input["content"]?.jsonPrimitive?.content ?: return """{"error": "Missing content"}"""
        val id = UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        val note = Note(id = id, title = title, content = content, createdAt = now, updatedAt = now)
        storageRepository.saveNote(note)
        return """{"success": true, "id": "$id", "message": "Note saved: $title"}"""
    }

    private fun getNotes(): String {
        val notes = storageRepository.getNotes()
        if (notes.isEmpty()) return """{"notes": [], "count": 0}"""
        val notesJson = notes.joinToString(",\n") { note ->
            """{"id": "${note.id}", "title": "${note.title.escapeJson()}", "content": "${note.content.escapeJson()}", "createdAt": ${note.createdAt}}"""
        }
        return """{"notes": [$notesJson], "count": ${notes.size}}"""
    }

    private fun deleteNote(input: Map<String, JsonElement>): String {
        val id = input["id"]?.jsonPrimitive?.content ?: return """{"error": "Missing id"}"""
        storageRepository.deleteNote(id)
        return """{"success": true, "message": "Note deleted"}"""
    }

    private fun rememberFact(input: Map<String, JsonElement>): String {
        val key = input["key"]?.jsonPrimitive?.content ?: return """{"error": "Missing key"}"""
        val value = input["value"]?.jsonPrimitive?.content ?: return """{"error": "Missing value"}"""
        val memory = UserMemory(key = key, value = value, updatedAt = System.currentTimeMillis())
        storageRepository.saveMemory(memory)
        return """{"success": true, "message": "Remembered: $key = $value"}"""
    }

    private fun recallFacts(): String {
        val memories = storageRepository.getAllMemories()
        if (memories.isEmpty()) return """{"memories": [], "count": 0}"""
        val memoriesJson = memories.joinToString(",\n") { mem ->
            """{"key": "${mem.key.escapeJson()}", "value": "${mem.value.escapeJson()}"}"""
        }
        return """{"memories": [$memoriesJson], "count": ${memories.size}}"""
    }

    private fun scheduleReminder(input: Map<String, JsonElement>): String {
        val title = input["title"]?.jsonPrimitive?.content ?: return """{"error": "Missing title"}"""
        val triggerStr = input["trigger_at_millis"]?.jsonPrimitive?.content
            ?: return """{"error": "Missing trigger_at_millis"}"""
        val triggerAt = triggerStr.toLongOrNull() ?: return """{"error": "Invalid timestamp"}"""

        val id = UUID.randomUUID().toString()
        val reminder = Reminder(id = id, title = title, triggerAtMillis = triggerAt)
        storageRepository.saveReminder(reminder)

        scheduleAlarm(id, title, triggerAt)

        return """{"success": true, "id": "$id", "message": "Reminder scheduled: $title"}"""
    }

    // ─── Alarm scheduling ─────────────────────────────────────────────────────

    private fun scheduleAlarm(id: String, title: String, triggerAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra(EXTRA_REMINDER_ID, id)
            putExtra(EXTRA_REMINDER_TITLE, title)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun String.escapeJson(): String =
        this.replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")

    companion object {
        const val EXTRA_REMINDER_ID = "reminder_id"
        const val EXTRA_REMINDER_TITLE = "reminder_title"
        private const val TAG = "ToolsService"
    }
}

// ─── Reminder Broadcast Receiver ─────────────────────────────────────────────

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminderId = intent.getStringExtra(ToolsService.EXTRA_REMINDER_ID) ?: return
        val title = intent.getStringExtra(ToolsService.EXTRA_REMINDER_TITLE) ?: "Reminder"

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create channel if needed
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Max Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Reminders from Max AI"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Max Reminder")
            .setContentText(title)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(reminderId.hashCode(), notification)
    }

    companion object {
        const val CHANNEL_ID = "max_reminders"
    }
}

// ─── Boot Receiver ────────────────────────────────────────────────────────────

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        // Re-schedule any pending reminders after reboot
        val storageRepo = StorageRepository(context)
        val reminders = storageRepo.getReminders()
        val now = System.currentTimeMillis()

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        reminders.filter { it.triggerAtMillis > now }.forEach { reminder ->
            // Re-schedule alarm directly
            val alarmIntent = Intent(context, ReminderReceiver::class.java).apply {
                putExtra(ToolsService.EXTRA_REMINDER_ID, reminder.id)
                putExtra(ToolsService.EXTRA_REMINDER_TITLE, reminder.title)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                reminder.id.hashCode(),
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    reminder.triggerAtMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, reminder.triggerAtMillis, pendingIntent)
            }
        }
    }
}

// ─── Notification Service (channel setup) ────────────────────────────────────

class NotificationService : android.app.Service() {
    override fun onBind(intent: Intent?): android.os.IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ReminderReceiver.CHANNEL_ID,
                "Max Reminders",
                NotificationManager.IMPORTANCE_HIGH
            )
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
}

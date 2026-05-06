package com.gindausd.max.services

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.CalendarContract
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.gindausd.max.MaxApplication
import com.gindausd.max.Note
import com.gindausd.max.Reminder
import com.gindausd.max.data.StorageRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.TimeUnit

class ToolsService private constructor() {

    fun handleToolCall(context: Context, name: String, input: Map<String, Any>): String {
        return when (name) {
            "get_datetime" -> handleGetDatetime()
            "get_weather" -> handleGetWeather(context, input)
            "save_note" -> handleSaveNote(context, input)
            "get_notes" -> handleGetNotes(context)
            "delete_note" -> handleDeleteNote(context, input)
            "remember_fact" -> handleRememberFact(context, input)
            "recall_facts" -> handleRecallFacts(context)
            "recall_places" -> handleRecallFacts(context)
            "schedule_reminder" -> handleScheduleReminder(context, input)
            "read_news" -> handleReadNews(context)
            "book_flight" -> handleBookFlight(context, input)
            "book_uber" -> handleBookUber(context, input)
            "compose_email" -> handleComposeEmail(context, input)
            "make_call" -> handleMakeCall(context, input)
            "get_directions" -> handleGetDirections(context, input)
            "create_calendar_event" -> handleCreateCalendarEvent(context, input)
            "get_calendar_events" -> handleGetCalendarEvents(context, input)
            "lookup_contact" -> handleLookupContact(context, input)
            "call_contact" -> handleCallContact(context, input)
            "send_sms" -> handleSendSms(context, input)
            else -> "Tool '$name' is not implemented."
        }
    }

    private fun handleGetWeather(context: Context, input: Map<String, Any>): String {
        val location = input["location"]?.toString()
        return runBlocking { WeatherService.getInstance().getWeather(context, location) }
    }

    private fun handleGetDatetime(): String {
        val sdf = SimpleDateFormat("EEEE, MMMM d, yyyy 'at' h:mm a", Locale.US)
        return "Current date and time: ${sdf.format(Date())}"
    }

    private fun handleSaveNote(context: Context, input: Map<String, Any>): String {
        val title = input["title"]?.toString() ?: "Untitled"
        val content = input["content"]?.toString() ?: ""
        val note = Note(
            id = UUID.randomUUID().toString(),
            title = title,
            content = content
        )
        runBlocking { StorageRepository.getInstance(context).saveNote(note) }
        return "Note '$title' saved successfully."
    }

    private fun handleGetNotes(context: Context): String {
        val notes = runBlocking { StorageRepository.getInstance(context).loadNotes() }
        if (notes.isEmpty()) return "No notes saved."
        val sdf = SimpleDateFormat("MMM d, yyyy", Locale.US)
        return notes.joinToString("\n\n") { note ->
            "**${note.title}** (${sdf.format(Date(note.createdAt))})\n${note.content}"
        }
    }

    private fun handleDeleteNote(context: Context, input: Map<String, Any>): String {
        val id = input["id"]?.toString() ?: return "Note ID required."
        runBlocking { StorageRepository.getInstance(context).deleteNote(id) }
        return "Note deleted."
    }

    private fun handleRememberFact(context: Context, input: Map<String, Any>): String {
        val key = input["key"]?.toString() ?: return "Key required."
        val value = input["value"]?.toString() ?: return "Value required."
        runBlocking { StorageRepository.getInstance(context).rememberFact(key, value) }
        return "I'll remember that: $key = $value"
    }

    private fun handleRecallFacts(context: Context): String {
        val facts = runBlocking { StorageRepository.getInstance(context).recallFacts() }
        if (facts.isEmpty()) return "No facts remembered yet."
        return facts.joinToString("\n") { "${it.key}: ${it.value}" }
    }

    private fun handleScheduleReminder(context: Context, input: Map<String, Any>): String {
        val title = input["title"]?.toString() ?: "Reminder"
        val body = input["body"]?.toString() ?: ""
        val delayMinutes = (input["delay_minutes"] as? Number)?.toLong() ?: 5L
        val reminderId = UUID.randomUUID().toString()
        val fireDate = System.currentTimeMillis() + delayMinutes * 60_000L

        val reminder = Reminder(
            id = reminderId,
            title = title,
            body = body,
            fireDate = fireDate
        )
        runBlocking { StorageRepository.getInstance(context).saveReminder(reminder) }

        val workRequest = OneTimeWorkRequestBuilder<ReminderWorker>()
            .setInitialDelay(delayMinutes, TimeUnit.MINUTES)
            .setInputData(workDataOf(
                "title" to title,
                "body" to body,
                "reminder_id" to reminderId
            ))
            .build()

        WorkManager.getInstance(context).enqueue(workRequest)

        val timeLabel = if (delayMinutes < 60) "$delayMinutes min" else "${delayMinutes / 60}h ${delayMinutes % 60}m"
        return "Reminder set for $timeLabel from now: \"$title\""
    }

    private fun handleLookupContact(context: Context, input: Map<String, Any>): String {
        val name = input["name"]?.toString() ?: return "Name required."
        val contacts = ContactsService.getInstance().lookupByName(context, name)
        if (contacts.isEmpty()) return "No contact found matching \"$name\"."
        return "Found:\n" + contacts.joinToString("\n") { "• ${it.displayName}: ${it.phoneNumber}" }
    }

    private fun handleCallContact(context: Context, input: Map<String, Any>): String {
        val name = input["name"]?.toString()
        val providedNumber = input["phone_number"]?.toString()

        val number = when {
            !providedNumber.isNullOrBlank() -> providedNumber
            !name.isNullOrBlank() -> {
                ContactsService.getInstance().findBestMatch(context, name)?.phoneNumber
                    ?: return "No contact found matching \"$name\"."
            }
            else -> return "Provide a contact name or phone number."
        }

        val intent = Intent(Intent.ACTION_DIAL).apply {
            data = Uri.parse("tel:$number")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
        return "Opening dialer${if (!name.isNullOrBlank()) " for $name" else ""} ($number)."
    }

    private fun handleSendSms(context: Context, input: Map<String, Any>): String {
        val name = input["name"]?.toString()
        val providedNumber = input["phone_number"]?.toString()
        val message = input["message"]?.toString() ?: ""

        val number = when {
            !providedNumber.isNullOrBlank() -> providedNumber
            !name.isNullOrBlank() -> {
                ContactsService.getInstance().findBestMatch(context, name)?.phoneNumber
                    ?: return "No contact found matching \"$name\"."
            }
            else -> return "Provide a contact name or phone number."
        }

        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("smsto:$number")
            putExtra("sms_body", message)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
        return "Opening SMS composer${if (!name.isNullOrBlank()) " for $name" else " for $number"}."
    }

    private fun handleReadNews(context: Context): String {
        return runBlocking {
            withContext(Dispatchers.IO) {
                try {
                    val url = java.net.URL("https://feeds.bbci.co.uk/news/rss.xml")
                    val connection = url.openConnection()
                    connection.connectTimeout = 5000
                    connection.readTimeout = 5000
                    val content = connection.getInputStream().bufferedReader().readText()

                    val headlines = mutableListOf<String>()
                    val titleRegex = Regex("<title><!\\[CDATA\\[(.+?)]]></title>|<title>([^<]+)</title>")
                    val matches = titleRegex.findAll(content).drop(1).take(5)
                    for (match in matches) {
                        val headline = (match.groupValues[1].ifEmpty { match.groupValues[2] }).trim()
                        if (headline.isNotEmpty()) headlines.add(headline)
                    }

                    if (headlines.isEmpty()) "Could not fetch news at this time."
                    else "Top BBC News Headlines:\n" + headlines.mapIndexed { i, h -> "${i + 1}. $h" }.joinToString("\n")
                } catch (e: Exception) {
                    "Unable to fetch news: ${e.message}"
                }
            }
        }
    }

    private fun handleBookFlight(context: Context, input: Map<String, Any>): String {
        val destination = input["destination"]?.toString() ?: return "Destination required."
        val origin = input["origin"]?.toString() ?: ""
        val encoded = Uri.encode("$origin to $destination flights")
        val uri = Uri.parse("https://www.kayak.com/flights/$encoded")
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
        return "Opening flight search for $destination."
    }

    private fun handleBookUber(context: Context, input: Map<String, Any>): String {
        val destination = input["destination"]?.toString() ?: return "Destination required."
        val encodedDest = Uri.encode(destination)
        val uri = Uri.parse("uber://?action=setPickup&dropoff[formatted_address]=$encodedDest")
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            // Uber not installed, open Play Store
            val fallback = Intent(Intent.ACTION_VIEW, Uri.parse("https://m.uber.com/looking")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(fallback)
        }
        return "Opening Uber to $destination."
    }

    private fun handleComposeEmail(context: Context, input: Map<String, Any>): String {
        val to = input["to"]?.toString() ?: ""
        val subject = input["subject"]?.toString() ?: ""
        val body = input["body"]?.toString() ?: ""
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("mailto:")
            putExtra(Intent.EXTRA_EMAIL, arrayOf(to))
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, body)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
        return "Opening email composer."
    }

    private fun handleMakeCall(context: Context, input: Map<String, Any>): String {
        val number = input["phone_number"]?.toString() ?: return "Phone number required."
        val intent = Intent(Intent.ACTION_DIAL).apply {
            data = Uri.parse("tel:$number")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
        return "Opening dialer for $number."
    }

    private fun handleGetDirections(context: Context, input: Map<String, Any>): String {
        val destination = input["destination"]?.toString() ?: return "Destination required."
        val origin = input["origin"]?.toString()
        val encodedDest = Uri.encode(destination)
        val uri = if (origin != null) {
            Uri.parse("https://www.google.com/maps/dir/${Uri.encode(origin)}/$encodedDest")
        } else {
            Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$encodedDest")
        }
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
        return "Opening directions to $destination."
    }

    private fun handleCreateCalendarEvent(context: Context, input: Map<String, Any>): String {
        val title = input["title"]?.toString() ?: "Event"
        val startTime = input["start_time"]?.toString() ?: return "Start time required."
        val endTime = input["end_time"]?.toString() ?: return "End time required."
        val location = input["location"]?.toString() ?: ""
        val description = input["description"]?.toString() ?: ""

        try {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
            val startMs = sdf.parse(startTime)?.time ?: System.currentTimeMillis()
            val endMs = sdf.parse(endTime)?.time ?: (startMs + 3600000L)

            val intent = Intent(Intent.ACTION_INSERT).apply {
                data = CalendarContract.Events.CONTENT_URI
                putExtra(CalendarContract.Events.TITLE, title)
                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMs)
                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMs)
                putExtra(CalendarContract.Events.EVENT_LOCATION, location)
                putExtra(CalendarContract.Events.DESCRIPTION, description)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            return "Opening calendar to create event: $title"
        } catch (e: Exception) {
            return "Could not create calendar event: ${e.message}"
        }
    }

    private fun handleGetCalendarEvents(context: Context, input: Map<String, Any>): String {
        val daysAhead = (input["days_ahead"] as? Number)?.toInt() ?: 7
        return try {
            val now = System.currentTimeMillis()
            val end = now + daysAhead.toLong() * 24 * 60 * 60 * 1000

            val projection = arrayOf(
                CalendarContract.Events.TITLE,
                CalendarContract.Events.DTSTART,
                CalendarContract.Events.DTEND,
                CalendarContract.Events.EVENT_LOCATION
            )
            val selection = "${CalendarContract.Events.DTSTART} >= ? AND ${CalendarContract.Events.DTSTART} <= ?"
            val selectionArgs = arrayOf(now.toString(), end.toString())

            val cursor = context.contentResolver.query(
                CalendarContract.Events.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                "${CalendarContract.Events.DTSTART} ASC"
            )

            val events = mutableListOf<String>()
            val sdf = SimpleDateFormat("EEE MMM d 'at' h:mm a", Locale.US)
            cursor?.use {
                while (it.moveToNext() && events.size < 10) {
                    val title = it.getString(0) ?: "Untitled"
                    val start = it.getLong(1)
                    val location = it.getString(3)
                    val line = "• $title — ${sdf.format(Date(start))}" + if (!location.isNullOrBlank()) " @ $location" else ""
                    events.add(line)
                }
            }

            if (events.isEmpty()) "No events in the next $daysAhead days."
            else "Upcoming events:\n" + events.joinToString("\n")
        } catch (e: Exception) {
            "Could not read calendar: ${e.message}"
        }
    }

    companion object {
        @Volatile private var INSTANCE: ToolsService? = null
        fun getInstance(): ToolsService =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: ToolsService().also { INSTANCE = it }
            }
    }
}

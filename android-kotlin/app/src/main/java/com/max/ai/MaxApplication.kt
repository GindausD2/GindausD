package com.max.ai

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import com.max.ai.services.AuthRepository
import com.max.ai.services.ClaudeService
import com.max.ai.services.ReminderReceiver
import com.max.ai.services.StorageRepository
import com.max.ai.services.ToolsService
import com.max.ai.services.VoiceService

class MaxApplication : Application() {

    // Singleton service instances (manual DI — no Hilt required)
    lateinit var authRepository: AuthRepository
        private set

    lateinit var storageRepository: StorageRepository
        private set

    lateinit var claudeService: ClaudeService
        private set

    lateinit var voiceService: VoiceService
        private set

    lateinit var toolsService: ToolsService
        private set

    override fun onCreate() {
        super.onCreate()

        // Initialize services
        authRepository = AuthRepository(this)
        storageRepository = StorageRepository(this)
        claudeService = ClaudeService()
        voiceService = VoiceService(this)
        toolsService = ToolsService(this, storageRepository)

        // Initialize TTS lazily in background
        voiceService.initTts()

        // Create notification channels
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ReminderReceiver.CHANNEL_ID,
                "Max Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Reminders scheduled through Max AI"
                enableVibration(true)
            }
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
}

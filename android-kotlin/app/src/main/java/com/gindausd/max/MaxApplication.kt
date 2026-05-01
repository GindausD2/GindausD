package com.gindausd.max

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

class MaxApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val briefingChannel = NotificationChannel(
            CHANNEL_BRIEFING,
            "Morning Briefing",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Daily morning briefing from Max"
        }

        val generalChannel = NotificationChannel(
            CHANNEL_GENERAL,
            "Max Notifications",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "General notifications from Max"
        }

        notificationManager.createNotificationChannels(listOf(briefingChannel, generalChannel))
    }

    companion object {
        const val CHANNEL_BRIEFING = "max_briefing"
        const val CHANNEL_GENERAL = "max_general"
    }
}

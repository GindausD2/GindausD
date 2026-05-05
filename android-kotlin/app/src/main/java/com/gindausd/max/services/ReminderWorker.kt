package com.gindausd.max.services

import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.gindausd.max.MaxApplication
import com.gindausd.max.data.StorageRepository

class ReminderWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val title = inputData.getString("title") ?: "Reminder from Max"
        val body = inputData.getString("body") ?: ""
        val reminderId = inputData.getString("reminder_id")

        val notification = NotificationCompat.Builder(applicationContext, MaxApplication.CHANNEL_GENERAL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        try {
            NotificationManagerCompat.from(applicationContext)
                .notify(System.currentTimeMillis().toInt(), notification)
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS not granted
        }

        if (reminderId != null) {
            StorageRepository.getInstance(applicationContext).deleteReminder(reminderId)
        }

        return Result.success()
    }
}

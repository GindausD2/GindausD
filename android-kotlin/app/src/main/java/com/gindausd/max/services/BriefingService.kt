package com.gindausd.max.services

import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.gindausd.max.MainActivity
import com.gindausd.max.MaxApplication
import java.util.Calendar
import java.util.concurrent.TimeUnit

class BriefingWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            val notificationId = System.currentTimeMillis().toInt()
            val tapIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                action = "com.gindausd.max.START_BRIEFING"
            }
            val tapPending = PendingIntent.getActivity(
                context, 1, tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(context, MaxApplication.CHANNEL_BRIEFING)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Good morning! ☀️")
                .setContentText("Your Max briefing is ready — tap to hear it.")
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setContentIntent(tapPending)
                .setAutoCancel(true)
                .build()

            try {
                NotificationManagerCompat.from(context).notify(notificationId, notification)
            } catch (e: SecurityException) {
                // Permission not granted
            }

            Result.success()
        } catch (e: Exception) {
            Result.failure()
        }
    }
}

object BriefingService {

    private const val WORK_TAG = "max_briefing_work"

    fun scheduleDailyBriefing(context: Context, hour: Int, minute: Int) {
        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        // If target time has already passed today, schedule for tomorrow
        if (target.before(now)) {
            target.add(Calendar.DAY_OF_YEAR, 1)
        }

        val initialDelayMs = target.timeInMillis - now.timeInMillis

        val periodicRequest = PeriodicWorkRequestBuilder<BriefingWorker>(1, TimeUnit.DAYS)
            .setInitialDelay(initialDelayMs, TimeUnit.MILLISECONDS)
            .addTag(WORK_TAG)
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WORK_TAG,
            ExistingPeriodicWorkPolicy.REPLACE,
            periodicRequest
        )
    }

    fun cancelBriefing(context: Context) {
        WorkManager.getInstance(context).cancelAllWorkByTag(WORK_TAG)
    }
}

package com.gindausd.max.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.gindausd.max.data.StorageRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        CoroutineScope(Dispatchers.IO).launch {
            val settings = StorageRepository.getInstance(context).loadSettings()
            if (settings.briefingEnabled) {
                BriefingService.scheduleDailyBriefing(
                    context,
                    settings.briefingHour,
                    settings.briefingMinute
                )
            }
        }
    }
}

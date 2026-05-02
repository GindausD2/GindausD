package com.gindausd.max.ui.widget

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.gindausd.max.MainActivity

class MaxGlanceWidget : GlanceAppWidget() {

    companion object {
        val LAST_MSG_KEY  = stringPreferencesKey("max_widget_last_message")
        val LAST_MSG_TIME = longPreferencesKey("max_widget_last_message_time")

        suspend fun push(context: Context, message: String) {
            try {
                val manager = GlanceAppWidgetManager(context)
                val ids = manager.getGlanceIds(MaxGlanceWidget::class.java)
                ids.forEach { id ->
                    updateAppWidgetState(context, PreferencesGlanceStateDefinition, id) { prefs ->
                        prefs.toMutablePreferences().apply {
                            this[LAST_MSG_KEY]  = message
                            this[LAST_MSG_TIME] = System.currentTimeMillis()
                        }
                    }
                    MaxGlanceWidget().update(context, id)
                }
            } catch (_: Exception) { /* widget not added — ignore */ }
        }
    }

    override val sizeMode = SizeMode.Responsive(
        setOf(
            DpSize(110.dp, 110.dp),  // small 2×2
            DpSize(250.dp, 110.dp)   // medium 4×2
        )
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs    = currentState<Preferences>()
            val lastMsg  = prefs[LAST_MSG_KEY]  ?: "Ready to help you."
            val lastTime = prefs[LAST_MSG_TIME]
            val isWide   = LocalSize.current.width >= 200.dp

            val tapIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.gindausd.max.START_LISTENING"
                flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }

            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .background(ColorProvider(Color(0xFF0F0804)))
                    .clickable(actionStartActivity(tapIntent)),
                contentAlignment = Alignment.Center
            ) {
                if (isWide) MediumContent(lastMsg, lastTime)
                else SmallContent()
            }
        }
    }
}

@Composable
private fun SmallContent() {
    Column(
        modifier = GlanceModifier.fillMaxSize().padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Orb: orange circle with specular highlight
        Box(
            modifier = GlanceModifier
                .size(52.dp)
                .background(ColorProvider(Color(0xFFE87800)))
                .cornerRadius(26.dp),
            contentAlignment = Alignment.TopStart
        ) {
            Box(
                modifier = GlanceModifier
                    .size(14.dp)
                    .padding(4.dp)
                    .background(ColorProvider(Color(0x70FFFFFF)))
                    .cornerRadius(7.dp)
            ) {}
        }
        Spacer(GlanceModifier.height(8.dp))
        Text(
            "Max",
            style = TextStyle(
                color      = ColorProvider(Color.White),
                fontSize   = 14.sp,
                fontWeight = FontWeight.Bold
            )
        )
        Spacer(GlanceModifier.height(2.dp))
        Text(
            "Tap to talk",
            style = TextStyle(
                color    = ColorProvider(Color(0xCCE87800)),
                fontSize = 11.sp
            )
        )
    }
}

@Composable
private fun MediumContent(lastMsg: String, lastMsgTime: Long?) {
    Row(
        modifier = GlanceModifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Left — orb + label
        Column(
            modifier = GlanceModifier.width(88.dp).fillMaxHeight().padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = GlanceModifier
                    .size(48.dp)
                    .background(ColorProvider(Color(0xFFE87800)))
                    .cornerRadius(24.dp),
                contentAlignment = Alignment.TopStart
            ) {
                Box(
                    modifier = GlanceModifier
                        .size(13.dp)
                        .padding(3.dp)
                        .background(ColorProvider(Color(0x70FFFFFF)))
                        .cornerRadius(6.dp)
                ) {}
            }
            Spacer(GlanceModifier.height(6.dp))
            Text(
                "Max",
                style = TextStyle(
                    color      = ColorProvider(Color.White),
                    fontSize   = 13.sp,
                    fontWeight = FontWeight.Bold
                )
            )
            Text(
                "AI Assistant",
                style = TextStyle(
                    color    = ColorProvider(Color(0x73FFFFFF)),
                    fontSize = 10.sp
                )
            )
        }

        // Divider
        Box(
            modifier = GlanceModifier
                .width(1.dp)
                .fillMaxHeight()
                .padding(vertical = 14.dp)
                .background(ColorProvider(Color(0x1AFFFFFF)))
        ) {}

        // Right — last message
        Column(
            modifier = GlanceModifier
                .defaultWeight()
                .fillMaxHeight()
                .padding(horizontal = 14.dp, vertical = 14.dp)
        ) {
            Text(
                text  = lastMsg,
                style = TextStyle(
                    color    = ColorProvider(Color(0xE0FFFFFF)),
                    fontSize = 12.sp
                ),
                maxLines = 4
            )
            Spacer(GlanceModifier.defaultWeight())
            if (lastMsgTime != null) {
                Text(
                    text  = relativeTime(lastMsgTime),
                    style = TextStyle(
                        color    = ColorProvider(Color(0xB3E87800)),
                        fontSize = 10.sp
                    )
                )
            }
        }
    }
}

private fun relativeTime(ms: Long): String {
    val diff = System.currentTimeMillis() - ms
    return when {
        diff < 60_000L       -> "just now"
        diff < 3_600_000L    -> "${diff / 60_000}m ago"
        diff < 86_400_000L   -> "${diff / 3_600_000}h ago"
        else                 -> "earlier"
    }
}

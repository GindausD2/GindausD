package com.max.ai.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// ─── Brand colors ─────────────────────────────────────────────────────────────

val Purple950 = Color(0xFF2D1B69)
val Purple700 = Color(0xFF4F46E5)
val Purple600 = Color(0xFF7C3AED)
val Purple400 = Color(0xFFC084FC)
val Purple200 = Color(0xFFE9D5FF)

val GlassWhite = Color(0x2EFFFFFF)       // 18% white
val GlassBorder = Color(0x40FFFFFF)      // 25% white
val GlassSurface = Color(0x1AFFFFFF)     // 10% white

val UserBubble = Color(0xFFE8E8EA)
val AiBubble = Color(0xFFFFFFFF)

val RecordingRed = Color(0xFFEF4444)
val ThinkingPurple = Color(0xFF7C3AED)
val SpeakingBlue = Color(0xFF3B82F6)

// ─── Gradient stops ───────────────────────────────────────────────────────────

val WelcomeGradientColors = listOf(
    Color(0xFF2D1B69),
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFFC084FC)
)

// ─── Orb gradient color sets by state ────────────────────────────────────────

val OrbIdleColors = listOf(
    Color(0xFF7C3AED),
    Color(0xFF4F46E5),
    Color(0xFF6D28D9)
)
val OrbListeningColors = listOf(
    Color(0xFFEF4444),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6)
)
val OrbThinkingColors = listOf(
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4)
)
val OrbSpeakingColors = listOf(
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6)
)

// ─── Light color scheme (home screen uses white bg) ──────────────────────────

private val MaxLightColors = lightColorScheme(
    primary = Purple600,
    onPrimary = Color.White,
    primaryContainer = Purple200,
    onPrimaryContainer = Purple950,
    secondary = Purple700,
    onSecondary = Color.White,
    background = Color.White,
    onBackground = Color(0xFF1A1A2E),
    surface = Color.White,
    onSurface = Color(0xFF1A1A2E),
    error = Color(0xFFB00020),
    onError = Color.White
)

// ─── Theme composable ─────────────────────────────────────────────────────────

@Composable
fun MaxAITheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = MaxLightColors,
        content = content
    )
}

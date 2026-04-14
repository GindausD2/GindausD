package com.max.ai.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// ─── Brand palette ─────────────────────────────────────────────────────────────

val Purple950  = Color(0xFF07041A)
val Purple900  = Color(0xFF160A38)
val Purple800  = Color(0xFF2D1B69)
val Purple700  = Color(0xFF4F46E5)
val Purple600  = Color(0xFF7C3AED)
val Purple400  = Color(0xFFA78BFA)
val Purple200  = Color(0xFFE9D5FF)

// Deep-space home background stops
val HomeBgTop    = Color(0xFF06030F)
val HomeBgMid    = Color(0xFF0E0620)
val HomeBgBottom = Color(0xFF100825)

// Glass surface tokens
val GlassWhite   = Color(0x24FFFFFF)   // ~14% white
val GlassBorder  = Color(0x80FFFFFF)   // ~50% white (for gradient start)
val GlassSurface = Color(0x1AFFFFFF)   // ~10% white

// Chat bubble colors
val UserBubbleStart = Color(0xFF8B21F0)
val UserBubbleEnd   = Color(0xFF4F1FDE)

// Status colors
val RecordingRed   = Color(0xFFEF4444)
val ThinkingPurple = Color(0xFF7C3AED)
val SpeakingBlue   = Color(0xFF3B82F6)

// ─── Welcome screen gradient ───────────────────────────────────────────────────

val WelcomeGradientColors = listOf(
    Color(0xFF07041A),
    Color(0xFF160A38),
    Color(0xFF2D1B69),
    Color(0xFF4F46E5),
    Color(0xFF7C3AED)
)

// ─── Orb gradient sets by state ───────────────────────────────────────────────

val OrbIdleColors = listOf(
    Color(0xFF8B21F0),
    Color(0xFF6D28D9),
    Color(0xFF4F46E5)
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

// ─── Dark color scheme ────────────────────────────────────────────────────────

private val MaxDarkColors = darkColorScheme(
    primary              = Purple400,
    onPrimary            = Color.White,
    primaryContainer     = Purple800,
    onPrimaryContainer   = Purple200,
    secondary            = Purple700,
    onSecondary          = Color.White,
    background           = HomeBgTop,
    onBackground         = Color.White,
    surface              = HomeBgMid,
    onSurface            = Color.White,
    surfaceVariant       = Color(0xFF1C1030),
    onSurfaceVariant     = Color.White.copy(alpha = 0.70f),
    error                = Color(0xFFCF6679),
    onError              = Color.White
)

// ─── Theme composable ─────────────────────────────────────────────────────────

@Composable
fun MaxAITheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = MaxDarkColors,
        content = content
    )
}

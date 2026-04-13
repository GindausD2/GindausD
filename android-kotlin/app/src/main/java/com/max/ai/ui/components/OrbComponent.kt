package com.max.ai.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.max.ai.OrbState
import com.max.ai.ui.theme.*
import kotlin.math.*

@Composable
fun OrbComponent(
    state: OrbState,
    modifier: Modifier = Modifier,
    size: Dp = 128.dp
) {
    // ─── Animations ───────────────────────────────────────────────────────────

    val infiniteTransition = rememberInfiniteTransition(label = "orb")

    // Rotation for gradient sweep
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = when (state) {
                    OrbState.IDLE -> 6000
                    OrbState.LISTENING -> 2000
                    OrbState.THINKING -> 1200
                    OrbState.SPEAKING -> 1800
                },
                easing = LinearEasing
            ),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotation"
    )

    // Outer pulse scale
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = when (state) {
            OrbState.IDLE -> 1.04f
            OrbState.LISTENING -> 1.15f
            OrbState.THINKING -> 1.08f
            OrbState.SPEAKING -> 1.12f
        },
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = when (state) {
                    OrbState.IDLE -> 3000
                    OrbState.LISTENING -> 600
                    OrbState.THINKING -> 900
                    OrbState.SPEAKING -> 500
                },
                easing = FastOutSlowInEasing
            ),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    // Opacity for outer glow ring
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.25f,
        targetValue = when (state) {
            OrbState.IDLE -> 0.4f
            OrbState.LISTENING -> 0.7f
            OrbState.THINKING -> 0.55f
            OrbState.SPEAKING -> 0.65f
        },
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glow"
    )

    // Secondary inner animation offset
    val innerOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 2 * PI.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(4000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "inner_offset"
    )

    // Colors for current state
    val orbColors = when (state) {
        OrbState.IDLE -> OrbIdleColors
        OrbState.LISTENING -> OrbListeningColors
        OrbState.THINKING -> OrbThinkingColors
        OrbState.SPEAKING -> OrbSpeakingColors
    }

    Canvas(
        modifier = modifier.size(size)
    ) {
        val center = Offset(this.size.width / 2f, this.size.height / 2f)
        val radius = (this.size.minDimension / 2f) * 0.82f
        val glowRadius = radius * pulseScale

        // ── Outer glow ring ─────────────────────────────────────────────────
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    orbColors.first().copy(alpha = glowAlpha * 0.5f),
                    orbColors.first().copy(alpha = 0f)
                ),
                center = center,
                radius = glowRadius * 1.35f
            ),
            radius = glowRadius * 1.35f,
            center = center
        )

        // ── Mid glow ring ────────────────────────────────────────────────────
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    orbColors.getOrElse(1) { orbColors.first() }.copy(alpha = glowAlpha * 0.65f),
                    Color.Transparent
                ),
                center = center,
                radius = glowRadius * 1.12f
            ),
            radius = glowRadius * 1.12f,
            center = center
        )

        // ── Main orb body (rotating sweep gradient) ──────────────────────────
        rotate(degrees = rotation, pivot = center) {
            drawCircle(
                brush = Brush.sweepGradient(
                    colors = orbColors + listOf(orbColors.first()),
                    center = center
                ),
                radius = radius,
                center = center
            )
        }

        // ── Inner specular highlight ─────────────────────────────────────────
        val highlightOffset = Offset(
            center.x - radius * 0.25f + cos(innerOffset) * radius * 0.12f,
            center.y - radius * 0.28f + sin(innerOffset) * radius * 0.10f
        )
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.45f),
                    Color.White.copy(alpha = 0f)
                ),
                center = highlightOffset,
                radius = radius * 0.38f
            ),
            radius = radius * 0.38f,
            center = highlightOffset
        )

        // ── Listening waveform rings ─────────────────────────────────────────
        if (state == OrbState.LISTENING) {
            for (i in 1..3) {
                val ringRadius = radius * (1f + i * 0.18f * pulseScale)
                val ringAlpha = (glowAlpha / i) * 0.6f
                drawCircle(
                    color = orbColors.first().copy(alpha = ringAlpha),
                    radius = ringRadius,
                    center = center,
                    style = Stroke(width = 1.5.dp.toPx())
                )
            }
        }

        // ── Thinking dot orbit ───────────────────────────────────────────────
        if (state == OrbState.THINKING) {
            val orbitRadius = radius * 1.22f
            val dotCount = 3
            for (i in 0 until dotCount) {
                val angle = rotation * (PI / 180f) + (2 * PI / dotCount) * i
                val dotX = center.x + cos(angle).toFloat() * orbitRadius
                val dotY = center.y + sin(angle).toFloat() * orbitRadius
                drawCircle(
                    color = orbColors.getOrElse(1) { orbColors.first() }.copy(alpha = 0.8f),
                    radius = 4.dp.toPx(),
                    center = Offset(dotX, dotY)
                )
            }
        }
    }
}

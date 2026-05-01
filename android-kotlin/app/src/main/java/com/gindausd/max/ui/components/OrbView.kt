package com.gindausd.max.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.Dp
import com.gindausd.max.OrbState
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun OrbView(
    state: OrbState,
    sizeDp: Dp,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "orb")

    val pulseDuration = state.pulseSpeed.toInt()

    val scale by infiniteTransition.animateFloat(
        initialValue = state.minScale,
        targetValue = state.maxScale,
        animationSpec = infiniteRepeatable(
            animation = tween(pulseDuration, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "orb_scale"
    )

    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(8000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "orb_rotation"
    )

    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.7f,
        animationSpec = infiniteRepeatable(
            animation = tween(pulseDuration / 2, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "orb_glow"
    )

    Canvas(
        modifier = modifier.size(sizeDp)
    ) {
        val center = Offset(size.width / 2f, size.height / 2f)
        val radius = (size.minDimension / 2f) * scale

        drawOuterGlow(center, radius, state.glowColor, glowAlpha)
        rotate(degrees = rotation, pivot = center) {
            drawShimmer(center, radius, state.primaryColor, state.secondaryColor)
        }
        drawOrbBody(center, radius, state.primaryColor, state.secondaryColor)
        drawSpecularHighlight(center, radius)
    }
}

private fun DrawScope.drawOuterGlow(
    center: Offset,
    radius: Float,
    glowColor: Color,
    alpha: Float
) {
    val glowRadius = radius * 1.4f
    val brush = Brush.radialGradient(
        colors = listOf(
            glowColor.copy(alpha = alpha * 0.6f),
            glowColor.copy(alpha = alpha * 0.3f),
            glowColor.copy(alpha = 0f)
        ),
        center = center,
        radius = glowRadius
    )
    drawCircle(brush = brush, radius = glowRadius, center = center)
}

private fun DrawScope.drawShimmer(
    center: Offset,
    radius: Float,
    primary: Color,
    secondary: Color
) {
    val shimmerRadius = radius * 0.9f
    val shimmerBrush = Brush.sweepGradient(
        colors = listOf(
            primary.copy(alpha = 0f),
            secondary.copy(alpha = 0.3f),
            primary.copy(alpha = 0f),
            primary.copy(alpha = 0f)
        ),
        center = center
    )
    drawCircle(brush = shimmerBrush, radius = shimmerRadius, center = center)
}

private fun DrawScope.drawOrbBody(
    center: Offset,
    radius: Float,
    primary: Color,
    secondary: Color
) {
    val highlightOffset = Offset(
        center.x - radius * 0.2f,
        center.y - radius * 0.2f
    )
    val bodyBrush = Brush.radialGradient(
        colors = listOf(
            secondary.copy(alpha = 0.9f),
            primary,
            primary.copy(red = primary.red * 0.6f, green = primary.green * 0.6f, blue = primary.blue * 0.6f)
        ),
        center = highlightOffset,
        radius = radius * 1.2f
    )
    drawCircle(brush = bodyBrush, radius = radius, center = center)
}

private fun DrawScope.drawSpecularHighlight(
    center: Offset,
    radius: Float
) {
    val highlightCenter = Offset(
        center.x - radius * 0.25f,
        center.y - radius * 0.25f
    )
    val highlightBrush = Brush.radialGradient(
        colors = listOf(
            Color.White.copy(alpha = 0.55f),
            Color.White.copy(alpha = 0.1f),
            Color.Transparent
        ),
        center = highlightCenter,
        radius = radius * 0.45f
    )
    drawCircle(
        brush = highlightBrush,
        radius = radius * 0.45f,
        center = highlightCenter
    )
}

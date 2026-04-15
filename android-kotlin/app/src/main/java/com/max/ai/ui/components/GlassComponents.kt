package com.max.ai.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ─── Brand palette ────────────────────────────────────────────────────────────

private val VioletStart = Color(0xFF8B21F0)
private val VioletEnd   = Color(0xFF4F1FDE)

// ─── Card Modifier (clean Material surface) ───────────────────────────────────

/**
 * Clean Material surface card — no glass effects.
 * Parameters kept for call-site compatibility.
 */
fun Modifier.glassCard(
    cornerRadius: Dp = 24.dp,
    alpha: Float = 0.14f,       // unused, kept for compat
    borderAlpha: Float = 0.50f  // unused, kept for compat
): Modifier = this
    .shadow(elevation = 4.dp, shape = RoundedCornerShape(cornerRadius), clip = false)
    .clip(RoundedCornerShape(cornerRadius))
    .background(Color(0xFF1C1030))

// ─── Card composable ──────────────────────────────────────────────────────────

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 24.dp,
    alpha: Float = 0.14f,
    borderAlpha: Float = 0.50f,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(cornerRadius),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF1C1030)),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        content = {
            Column(
                modifier = Modifier.padding(20.dp),
                content = content
            )
        }
    )
}

// ─── Text field ───────────────────────────────────────────────────────────────

/**
 * OutlinedTextField styled for dark/violet backgrounds (welcome screen).
 */
@Composable
fun GlassTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "",
    visualTransformation: VisualTransformation = VisualTransformation.None,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    singleLine: Boolean = true,
    leadingIcon: @Composable (() -> Unit)? = null,
    trailingIcon: @Composable (() -> Unit)? = null
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier.fillMaxWidth(),
        placeholder = {
            Text(text = placeholder, color = Color.White.copy(alpha = 0.45f), fontSize = 15.sp)
        },
        textStyle = TextStyle(color = Color.White, fontSize = 15.sp),
        visualTransformation = visualTransformation,
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        singleLine = singleLine,
        leadingIcon = leadingIcon,
        trailingIcon = trailingIcon,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor      = Color(0xFFA78BFA),
            unfocusedBorderColor    = Color.White.copy(alpha = 0.30f),
            cursorColor             = Color(0xFFA78BFA),
            focusedContainerColor   = Color(0x14FFFFFF),
            unfocusedContainerColor = Color(0x0DFFFFFF)
        ),
        shape = RoundedCornerShape(14.dp)
    )
}

// ─── Primary button (violet brand, no glass) ──────────────────────────────────

@Composable
fun GlassButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    fillWidth: Boolean = true
) {
    Button(
        onClick = onClick,
        modifier = modifier
            .then(if (fillWidth) Modifier.fillMaxWidth() else Modifier)
            .height(52.dp),
        enabled = enabled && !isLoading,
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor         = Color(0xFF7C3AED),
            contentColor           = Color.White,
            disabledContainerColor = Color(0xFF7C3AED).copy(alpha = 0.40f),
            disabledContentColor   = Color.White.copy(alpha = 0.50f)
        ),
        elevation = ButtonDefaults.buttonElevation(defaultElevation = 2.dp, pressedElevation = 4.dp)
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                color = Color.White,
                strokeWidth = 2.dp
            )
        } else {
            Text(text = text, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        }
    }
}

// ─── Pill / outline button ────────────────────────────────────────────────────

@Composable
fun GlassPillButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.height(46.dp),
        enabled = enabled,
        shape = RoundedCornerShape(26.dp),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor         = Color.White,
            containerColor       = Color(0x1AFFFFFF),
            disabledContentColor = Color.White.copy(alpha = 0.40f)
        ),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.40f))
    ) {
        Text(text = text, fontWeight = FontWeight.Medium, fontSize = 14.sp)
    }
}

// ─── Message bubble ───────────────────────────────────────────────────────────

@Composable
fun MessageBubble(
    content: String,
    isUser: Boolean,
    isStreaming: Boolean = false,
    modifier: Modifier = Modifier
) {
    val alignment = if (isUser) Alignment.CenterEnd else Alignment.CenterStart
    Box(
        modifier = modifier.fillMaxWidth(),
        contentAlignment = alignment
    ) {
        val bubbleShape = RoundedCornerShape(
            topStart    = if (isUser) 20.dp else 6.dp,
            topEnd      = if (isUser) 6.dp else 20.dp,
            bottomStart = 20.dp,
            bottomEnd   = 20.dp
        )
        val displayText = if (isStreaming && content.isEmpty()) "..." else content

        if (isUser) {
            // Violet brand gradient — solid, no glass layers
            Box(
                modifier = Modifier
                    .widthIn(max = 300.dp)
                    .clip(bubbleShape)
                    .background(
                        Brush.linearGradient(colors = listOf(VioletStart, VioletEnd))
                    )
                    .padding(horizontal = 16.dp, vertical = 11.dp)
            ) {
                Text(text = displayText, color = Color.White, fontSize = 15.sp, lineHeight = 22.sp)
            }
        } else {
            // AI bubble: Material surface variant
            Surface(
                modifier = Modifier.widthIn(max = 300.dp),
                shape = bubbleShape,
                color = MaterialTheme.colorScheme.surfaceVariant,
                tonalElevation = 2.dp
            ) {
                Text(
                    text = displayText,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 15.sp,
                    lineHeight = 22.sp,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 11.dp)
                )
            }
        }
    }
}

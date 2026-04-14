package com.max.ai.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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

// ─── Liquid-glass Modifier ────────────────────────────────────────────────────

/**
 * Multi-layer glass treatment:
 *   1. Base semi-transparent fill
 *   2. Specular top-gradient (simulates light hitting the top face)
 *   3. Gradient border (bright top-left → transparent bottom-right)
 */
fun Modifier.glassCard(
    cornerRadius: Dp = 24.dp,
    alpha: Float = 0.14f,
    borderAlpha: Float = 0.50f
): Modifier = this
    .shadow(
        elevation = 16.dp,
        shape = RoundedCornerShape(cornerRadius),
        ambientColor = Color.Black.copy(alpha = 0.40f),
        spotColor = Color.Black.copy(alpha = 0.30f)
    )
    .clip(RoundedCornerShape(cornerRadius))
    .background(Color.White.copy(alpha = alpha))
    .background(
        // Specular top highlight
        Brush.verticalGradient(
            colors = listOf(
                Color.White.copy(alpha = 0.22f),
                Color.White.copy(alpha = 0.08f),
                Color.Transparent
            ),
            startY = 0f,
            endY = Float.MAX_VALUE
        )
    )
    .border(
        width = 1.dp,
        brush = Brush.linearGradient(
            colors = listOf(
                Color.White.copy(alpha = borderAlpha),
                Color.White.copy(alpha = 0.20f),
                Color.White.copy(alpha = 0.04f),
                Color.Transparent
            )
        ),
        shape = RoundedCornerShape(cornerRadius)
    )

// ─── GlassCard composable ─────────────────────────────────────────────────────

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 24.dp,
    alpha: Float = 0.14f,
    borderAlpha: Float = 0.50f,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .glassCard(cornerRadius = cornerRadius, alpha = alpha, borderAlpha = borderAlpha)
            .padding(20.dp),
        content = content
    )
}

// ─── Liquid-glass text field ──────────────────────────────────────────────────

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
    val shape = RoundedCornerShape(14.dp)
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Color.White.copy(alpha = 0.09f))
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.14f),
                        Color.Transparent
                    ),
                    endY = 80f
                )
            ),
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
            focusedBorderColor    = Color.White.copy(alpha = 0.55f),
            unfocusedBorderColor  = Color.White.copy(alpha = 0.22f),
            cursorColor           = Color(0xFFA78BFA),
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent
        ),
        shape = shape
    )
}

// ─── Liquid-glass primary button ──────────────────────────────────────────────

@Composable
fun GlassButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    fillWidth: Boolean = true
) {
    val shape = RoundedCornerShape(16.dp)
    Box(
        modifier = modifier
            .then(if (fillWidth) Modifier.fillMaxWidth() else Modifier)
            .height(52.dp)
            .shadow(
                elevation = 12.dp,
                shape = shape,
                ambientColor = VioletStart.copy(alpha = 0.40f),
                spotColor = VioletStart.copy(alpha = 0.30f)
            )
            .clip(shape)
            .background(
                Brush.linearGradient(
                    colors = listOf(VioletStart, VioletEnd)
                )
            )
            // Specular
            .background(
                Brush.verticalGradient(
                    colors = listOf(Color.White.copy(alpha = 0.22f), Color.Transparent),
                    endY = 80f
                )
            )
            .border(
                1.dp,
                Brush.linearGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.45f),
                        Color.White.copy(alpha = 0.06f)
                    )
                ),
                shape
            ),
        contentAlignment = Alignment.Center
    ) {
        Button(
            onClick = onClick,
            modifier = Modifier.fillMaxSize(),
            enabled = enabled && !isLoading,
            shape = shape,
            colors = ButtonDefaults.buttonColors(
                containerColor       = Color.Transparent,
                contentColor         = Color.White,
                disabledContainerColor = Color.Transparent,
                disabledContentColor = Color.White.copy(alpha = 0.45f)
            ),
            elevation = ButtonDefaults.buttonElevation(0.dp, 0.dp, 0.dp)
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
}

// ─── Liquid-glass pill (outline) button ───────────────────────────────────────

@Composable
fun GlassPillButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    val shape = RoundedCornerShape(26.dp)
    Box(
        modifier = modifier
            .height(46.dp)
            .clip(shape)
            .background(Color.White.copy(alpha = 0.10f))
            .background(
                Brush.verticalGradient(
                    colors = listOf(Color.White.copy(alpha = 0.18f), Color.Transparent),
                    endY = 60f
                )
            )
            .border(
                1.dp,
                Brush.linearGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.50f),
                        Color.White.copy(alpha = 0.08f)
                    )
                ),
                shape
            ),
        contentAlignment = Alignment.Center
    ) {
        OutlinedButton(
            onClick = onClick,
            modifier = Modifier.fillMaxSize(),
            enabled = enabled,
            shape = shape,
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor        = Color.White,
                containerColor      = Color.Transparent,
                disabledContentColor = Color.White.copy(alpha = 0.4f)
            ),
            border = null
        ) {
            Text(text = text, fontWeight = FontWeight.Medium, fontSize = 14.sp)
        }
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
            topStart    = if (isUser) 20.dp else 5.dp,
            topEnd      = if (isUser) 5.dp else 20.dp,
            bottomStart = 20.dp,
            bottomEnd   = 20.dp
        )

        if (isUser) {
            // Violet glass bubble
            Box(
                modifier = Modifier
                    .widthIn(max = 300.dp)
                    .shadow(
                        elevation = 10.dp,
                        shape = bubbleShape,
                        ambientColor = VioletStart.copy(alpha = 0.40f),
                        spotColor = VioletStart.copy(alpha = 0.25f)
                    )
                    .clip(bubbleShape)
                    .background(
                        Brush.linearGradient(
                            colors = listOf(VioletStart, VioletEnd)
                        )
                    )
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(Color.White.copy(alpha = 0.22f), Color.Transparent),
                            endY = 80f
                        )
                    )
                    .border(
                        0.75.dp,
                        Brush.linearGradient(
                            colors = listOf(
                                Color.White.copy(alpha = 0.40f),
                                Color.White.copy(alpha = 0.04f)
                            )
                        ),
                        bubbleShape
                    )
                    .padding(horizontal = 16.dp, vertical = 11.dp)
            ) {
                Text(
                    text = if (isStreaming && content.isEmpty()) "..." else content,
                    color = Color.White,
                    fontSize = 15.sp,
                    lineHeight = 22.sp
                )
            }
        } else {
            // Frosted glass AI bubble
            Box(
                modifier = Modifier
                    .widthIn(max = 300.dp)
                    .shadow(
                        elevation = 6.dp,
                        shape = bubbleShape,
                        ambientColor = Color.Black.copy(alpha = 0.30f),
                        spotColor = Color.Black.copy(alpha = 0.20f)
                    )
                    .clip(bubbleShape)
                    .background(Color.White.copy(alpha = 0.13f))
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(Color.White.copy(alpha = 0.16f), Color.Transparent),
                            endY = 80f
                        )
                    )
                    .border(
                        0.75.dp,
                        Brush.linearGradient(
                            colors = listOf(
                                Color.White.copy(alpha = 0.35f),
                                Color.White.copy(alpha = 0.04f)
                            )
                        ),
                        bubbleShape
                    )
                    .padding(horizontal = 16.dp, vertical = 11.dp)
            ) {
                Text(
                    text = if (isStreaming && content.isEmpty()) "..." else content,
                    color = Color.White.copy(alpha = 0.92f),
                    fontSize = 15.sp,
                    lineHeight = 22.sp
                )
            }
        }
    }
}

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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ─── Glass card modifier extension ───────────────────────────────────────────

fun Modifier.glassCard(
    cornerRadius: Dp = 22.dp,
    alpha: Float = 0.18f,
    borderAlpha: Float = 0.25f
): Modifier = this
    .clip(RoundedCornerShape(cornerRadius))
    .background(Color.White.copy(alpha = alpha))
    .border(
        width = 1.dp,
        color = Color.White.copy(alpha = borderAlpha),
        shape = RoundedCornerShape(cornerRadius)
    )

// ─── GlassCard composable ─────────────────────────────────────────────────────

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 22.dp,
    alpha: Float = 0.18f,
    borderAlpha: Float = 0.25f,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius))
            .background(Color.White.copy(alpha = alpha))
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = borderAlpha),
                shape = RoundedCornerShape(cornerRadius)
            )
            .padding(20.dp),
        content = content
    )
}

// ─── Glass text field ─────────────────────────────────────────────────────────

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
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.12f)),
        placeholder = {
            Text(
                text = placeholder,
                color = Color.White.copy(alpha = 0.55f),
                fontSize = 15.sp
            )
        },
        textStyle = TextStyle(color = Color.White, fontSize = 15.sp),
        visualTransformation = visualTransformation,
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        singleLine = singleLine,
        leadingIcon = leadingIcon,
        trailingIcon = trailingIcon,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = Color.White.copy(alpha = 0.6f),
            unfocusedBorderColor = Color.White.copy(alpha = 0.3f),
            cursorColor = Color.White,
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent
        ),
        shape = RoundedCornerShape(14.dp)
    )
}

// ─── Glass primary button ─────────────────────────────────────────────────────

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
            .height(50.dp),
        enabled = enabled && !isLoading,
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.White.copy(alpha = 0.25f),
            contentColor = Color.White,
            disabledContainerColor = Color.White.copy(alpha = 0.10f),
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
            Text(
                text = text,
                fontWeight = FontWeight.SemiBold,
                fontSize = 16.sp
            )
        }
    }
}

// ─── Glass outline (pill) button ──────────────────────────────────────────────

@Composable
fun GlassPillButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.height(44.dp),
        enabled = enabled,
        shape = RoundedCornerShape(22.dp),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = Color.White,
            containerColor = Color.White.copy(alpha = 0.12f)
        ),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            Color.White.copy(alpha = 0.45f)
        )
    ) {
        Text(
            text = text,
            fontWeight = FontWeight.Medium,
            fontSize = 14.sp
        )
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
    val bgColor = if (isUser) Color(0xFFE8E8EA) else Color.White
    val textColor = Color(0xFF1A1A2E)
    val alignment = if (isUser) Alignment.CenterEnd else Alignment.CenterStart

    Box(
        modifier = modifier.fillMaxWidth(),
        contentAlignment = alignment
    ) {
        val bubbleShape = RoundedCornerShape(
            topStart = if (isUser) 18.dp else 4.dp,
            topEnd = if (isUser) 4.dp else 18.dp,
            bottomStart = 18.dp,
            bottomEnd = 18.dp
        )
        Row(
            modifier = Modifier
                .widthIn(max = 300.dp)
                .then(
                    if (!isUser) Modifier.shadow(elevation = 2.dp, shape = bubbleShape)
                    else Modifier
                )
                .clip(bubbleShape)
                .background(bgColor)
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            Text(
                text = if (isStreaming && content.isEmpty()) "..." else content,
                color = textColor,
                fontSize = 15.sp,
                lineHeight = 22.sp
            )
        }
    }
}

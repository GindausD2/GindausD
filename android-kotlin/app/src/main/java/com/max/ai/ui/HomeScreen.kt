package com.max.ai.ui

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.max.ai.OrbState
import com.max.ai.ui.components.MessageBubble
import com.max.ai.ui.components.OrbComponent
import com.max.ai.ui.theme.RecordingRed
import com.max.ai.ui.theme.ThinkingPurple
import com.max.ai.viewmodels.HomeViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel,
    onNavigateToSettings: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val listState = rememberLazyListState()

    // Live clock state
    var clockText by remember { mutableStateOf(formatTime()) }
    LaunchedEffect(Unit) {
        while (isActive) {
            clockText = formatTime()
            delay(1000L)
        }
    }

    // Auto-scroll to bottom when new messages arrive
    LaunchedEffect(uiState.messages.size) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.lastIndex)
        }
    }

    // Error Snackbar host
    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(uiState.error) {
        if (uiState.error != null) {
            snackbarHostState.showSnackbar(
                message = uiState.error!!,
                duration = SnackbarDuration.Short
            )
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            HomeTopBar(
                onRefresh = viewModel::refreshHistory,
                onSettings = onNavigateToSettings
            )
        },
        containerColor = Color.White
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // ── Chat transcript ──────────────────────────────────────────────
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                contentPadding = PaddingValues(vertical = 12.dp)
            ) {
                if (uiState.messages.isEmpty()) {
                    item {
                        EmptyTranscriptPlaceholder()
                    }
                }
                items(
                    items = uiState.messages,
                    key = { it.id }
                ) { message ->
                    MessageBubble(
                        content = message.content,
                        isUser = message.role == "user",
                        isStreaming = message.isStreaming
                    )
                }
            }

            // ── Status indicator ─────────────────────────────────────────────
            AnimatedVisibility(
                visible = uiState.statusMessage != null,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 4.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(
                            if (uiState.isRecording) RecordingRed.copy(alpha = 0.12f)
                            else ThinkingPurple.copy(alpha = 0.10f)
                        )
                        .padding(horizontal = 14.dp, vertical = 8.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        // Pulsing dot
                        PulsingDot(
                            color = if (uiState.isRecording) RecordingRed else ThinkingPurple
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = uiState.statusMessage ?: "",
                            color = if (uiState.isRecording) RecordingRed else ThinkingPurple,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }

            // ── Bottom: clock + orb + mic button ─────────────────────────────
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 24.dp, top = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Live clock
                Text(
                    text = clockText,
                    fontSize = 13.sp,
                    color = Color(0xFF9CA3AF),
                    fontWeight = FontWeight.Medium,
                    letterSpacing = 1.sp
                )

                Spacer(Modifier.height(12.dp))

                // Orb
                OrbComponent(
                    state = uiState.orbState,
                    size = 128.dp
                )

                Spacer(Modifier.height(16.dp))

                // Mic button
                MicButton(
                    isRecording = uiState.isRecording,
                    isThinking = uiState.isThinking,
                    onClick = viewModel::onMicPressed
                )
            }

            // ── Bottom status bar ─────────────────────────────────────────────
            BottomStatusBar(
                isRecording = uiState.isRecording,
                isThinking = uiState.isThinking
            )
        }
    }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeTopBar(
    onRefresh: () -> Unit,
    onSettings: () -> Unit
) {
    TopAppBar(
        title = {
            Text(
                text = "Max",
                fontWeight = FontWeight.Bold,
                fontSize = 22.sp,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
                color = Color(0xFF1A1A2E)
            )
        },
        navigationIcon = {
            IconButton(onClick = onRefresh) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "Refresh",
                    tint = Color(0xFF6B7280)
                )
            }
        },
        actions = {
            IconButton(onClick = onSettings) {
                Icon(
                    imageVector = Icons.Default.Settings,
                    contentDescription = "Settings",
                    tint = Color(0xFF6B7280)
                )
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = Color.White,
            titleContentColor = Color(0xFF1A1A2E)
        )
    )
}

// ─── Mic button ───────────────────────────────────────────────────────────────

@Composable
private fun MicButton(
    isRecording: Boolean,
    isThinking: Boolean,
    onClick: () -> Unit
) {
    val scale by animateFloatAsState(
        targetValue = if (isRecording) 1.12f else 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "mic_scale"
    )

    val bgColor = when {
        isRecording -> RecordingRed
        isThinking -> ThinkingPurple.copy(alpha = 0.6f)
        else -> Color(0xFF7C3AED)
    }

    IconButton(
        onClick = onClick,
        enabled = !isThinking,
        modifier = Modifier
            .scale(scale)
            .size(60.dp)
            .clip(CircleShape)
            .background(bgColor)
    ) {
        Icon(
            imageVector = if (isRecording)
                Icons.Default.Settings // mic-off placeholder; use real mic icons
            else
                Icons.Default.Settings, // mic placeholder
            contentDescription = if (isRecording) "Stop recording" else "Start recording",
            tint = Color.White,
            modifier = Modifier.size(28.dp)
        )
    }
}

// ─── Pulsing dot ──────────────────────────────────────────────────────────────

@Composable
private fun PulsingDot(color: Color) {
    val infiniteTransition = rememberInfiniteTransition(label = "dot_pulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 0.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dot_alpha"
    )
    Box(
        modifier = Modifier
            .size(8.dp)
            .clip(CircleShape)
            .background(color.copy(alpha = alpha))
    )
}

// ─── Bottom status bar ────────────────────────────────────────────────────────

@Composable
private fun BottomStatusBar(
    isRecording: Boolean,
    isThinking: Boolean
) {
    AnimatedVisibility(
        visible = isRecording || isThinking,
        enter = expandVertically(expandFrom = Alignment.Bottom),
        exit = shrinkVertically(shrinkTowards = Alignment.Bottom)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .background(
                    if (isRecording) RecordingRed
                    else ThinkingPurple
                )
        )
    }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

@Composable
private fun EmptyTranscriptPlaceholder() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "Hi! I'm Max.",
            fontSize = 20.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color(0xFF1A1A2E)
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = "Tap the mic to start a conversation.",
            fontSize = 15.sp,
            color = Color(0xFF9CA3AF),
            textAlign = TextAlign.Center
        )
    }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

private fun formatTime(): String {
    val sdf = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
    return sdf.format(Date())
}

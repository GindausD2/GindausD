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
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Image
import com.max.ai.OrbState
import com.max.ai.R
import com.max.ai.ui.components.MessageBubble
import com.max.ai.ui.components.OrbComponent
import com.max.ai.ui.theme.HomeBgBottom
import com.max.ai.ui.theme.HomeBgMid
import com.max.ai.ui.theme.HomeBgTop
import com.max.ai.ui.theme.RecordingRed
import com.max.ai.ui.theme.ThinkingPurple
import com.max.ai.viewmodels.HomeViewModel

private val AccentViolet = Color(0xFF7C3AED)
private val AccentIndigo = Color(0xFF4F46E5)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel,
    onNavigateToSettings: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val listState = rememberLazyListState()

    LaunchedEffect(uiState.messages.size) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.lastIndex)
        }
    }

    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(uiState.error) {
        if (uiState.error != null) {
            snackbarHostState.showSnackbar(
                message = uiState.error!!,
                duration = SnackbarDuration.Short
            )
        }
    }

    // ── Deep-space gradient background ────────────────────────────────────────
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(colors = listOf(HomeBgTop, HomeBgMid, HomeBgBottom)))
    ) {
        Scaffold(
            snackbarHost = { SnackbarHost(snackbarHostState) },
            topBar = {
                MaxTopBar(
                    onRefresh = viewModel::refreshHistory,
                    onSettings = onNavigateToSettings
                )
            },
            containerColor = Color.Transparent
        ) { paddingValues ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
            ) {
                // ── Chat transcript ──────────────────────────────────────────
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    contentPadding = PaddingValues(vertical = 14.dp)
                ) {
                    if (uiState.messages.isEmpty()) {
                        item { EmptyTranscriptPlaceholder() }
                    }
                    items(items = uiState.messages, key = { it.id }) { message ->
                        MessageBubble(
                            content = message.content,
                            isUser = message.role == "user",
                            isStreaming = message.isStreaming
                        )
                    }
                }

                // ── Status indicator ─────────────────────────────────────────
                AnimatedVisibility(
                    visible = uiState.statusMessage != null,
                    enter = fadeIn() + expandVertically(),
                    exit  = fadeOut() + shrinkVertically()
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp, vertical = 4.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .background(
                                if (uiState.isRecording) RecordingRed.copy(alpha = 0.14f)
                                else ThinkingPurple.copy(alpha = 0.12f)
                            )
                            .padding(horizontal = 14.dp, vertical = 8.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            PulsingDot(color = if (uiState.isRecording) RecordingRed else ThinkingPurple)
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

                // ── Bottom dock ───────────────────────────────────────────────
                BottomDock(
                    orbState = uiState.orbState,
                    isRecording = uiState.isRecording,
                    isThinking = uiState.isThinking,
                    onMicPressed = viewModel::onMicPressed
                )
            }
        }
    }
}

// ─── Top bar ─────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MaxTopBar(
    onRefresh: () -> Unit,
    onSettings: () -> Unit
) {
    TopAppBar(
        title = {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                Image(
                    painter = painterResource(id = R.drawable.ic_max_logo),
                    contentDescription = "Max",
                    modifier = Modifier.height(28.dp).width(64.dp),
                    colorFilter = ColorFilter.tint(Color.White)
                )
            }
        },
        navigationIcon = {
            IconButton(onClick = onRefresh) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "New chat",
                    tint = Color.White.copy(alpha = 0.70f)
                )
            }
        },
        actions = {
            IconButton(onClick = onSettings) {
                Icon(
                    imageVector = Icons.Default.Settings,
                    contentDescription = "Settings",
                    tint = Color.White.copy(alpha = 0.70f)
                )
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor      = Color(0xFF0E0620),
            titleContentColor   = Color.White
        )
    )
}

// ─── Bottom dock (clean Material surface) ─────────────────────────────────────

@Composable
private fun BottomDock(
    orbState: OrbState,
    isRecording: Boolean,
    isThinking: Boolean,
    onMicPressed: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 10.dp),
        shape = RoundedCornerShape(32.dp),
        color = Color(0xFF1A0D35),
        tonalElevation = 8.dp,
        shadowElevation = 12.dp
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, top = 24.dp, bottom = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            OrbComponent(state = orbState, size = 128.dp)
            Spacer(Modifier.height(20.dp))
            MicButton(
                isRecording = isRecording,
                isThinking = isThinking,
                onClick = onMicPressed
            )
        }
    }
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

    val baseColor = when {
        isRecording -> RecordingRed
        isThinking  -> ThinkingPurple.copy(alpha = 0.6f)
        else        -> AccentViolet
    }

    IconButton(
        onClick = onClick,
        enabled = !isThinking,
        modifier = Modifier
            .scale(scale)
            .size(60.dp)
            .clip(CircleShape)
            .background(baseColor)
    ) {
        Icon(
            imageVector = if (isRecording) Icons.Default.MicOff else Icons.Default.Mic,
            contentDescription = if (isRecording) "Stop" else "Record",
            tint = Color.White,
            modifier = Modifier.size(26.dp)
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

// ─── Empty state ──────────────────────────────────────────────────────────────

@Composable
private fun EmptyTranscriptPlaceholder() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 50.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "Hi! I'm Max.",
            fontSize = 22.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = "Tap the mic to start a conversation.",
            fontSize = 15.sp,
            color = Color.White.copy(alpha = 0.45f),
            textAlign = TextAlign.Center
        )
    }
}

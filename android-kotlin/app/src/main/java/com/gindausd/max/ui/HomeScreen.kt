package com.gindausd.max.ui

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gindausd.max.ConversationState
import com.gindausd.max.OrbState
import com.gindausd.max.ui.components.OrbView
import com.gindausd.max.ui.components.TranscriptBubble
import com.gindausd.max.ui.theme.BackgroundDark
import com.gindausd.max.ui.theme.StatusListening
import com.gindausd.max.ui.theme.StatusSpeaking
import com.gindausd.max.ui.theme.StatusThinking
import com.gindausd.max.viewmodels.HomeViewModel
import kotlinx.coroutines.launch

@Composable
fun HomeScreen(
    onNavigateToSettings: () -> Unit,
    onNavigateToHistory: () -> Unit,
    viewModel: HomeViewModel = viewModel()
) {
    val context = LocalContext.current
    val messages by viewModel.messages.collectAsStateWithLifecycle()
    val conversationState by viewModel.conversationState.collectAsStateWithLifecycle()
    val orbState by viewModel.orbState.collectAsStateWithLifecycle()
    val pendingImage by viewModel.pendingImage.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    var hasAudioPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED
        )
    }

    val audioPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasAudioPermission = granted
        if (granted) viewModel.handleOrbTap()
    }

    val imagePickerLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            val bitmap = android.provider.MediaStore.Images.Media.getBitmap(context.contentResolver, it)
            viewModel.setPendingImage(bitmap)
        }
    }

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    LaunchedEffect(errorMessage) {
        errorMessage?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.dismissError()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(BackgroundDark)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Top Bar
            HomeTopBar(
                onSettingsClick = onNavigateToSettings,
                onHistoryClick = onNavigateToHistory
            )

            // Transcript Area
            if (messages.isEmpty()) {
                EmptyStateContent(
                    orbState = orbState,
                    modifier = Modifier.weight(1f)
                )
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .weight(1f)
                        .padding(vertical = 8.dp)
                ) {
                    items(messages, key = { it.id }) { message ->
                        TranscriptBubble(message = message)
                    }
                    item { Spacer(modifier = Modifier.height(100.dp)) }
                }
            }
        }

        // Bottom dock area
        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 24.dp, start = 16.dp, end = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Status pill
            AnimatedVisibility(
                visible = conversationState != ConversationState.IDLE,
                enter = fadeIn() + slideInVertically(),
                exit = fadeOut() + slideOutVertically()
            ) {
                StatusPill(state = conversationState)
                Spacer(modifier = Modifier.height(8.dp))
            }

            // Image pending bar
            AnimatedVisibility(visible = pendingImage != null) {
                ImagePendingBar(
                    onSend = {
                        pendingImage?.let { viewModel.sendImageMessage(it) }
                    },
                    onCancel = { viewModel.setPendingImage(null) }
                )
                Spacer(modifier = Modifier.height(8.dp))
            }

            // Main dock
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        color = Color(0xDD1A1008),
                        shape = RoundedCornerShape(32.dp)
                    )
                    .padding(horizontal = 24.dp, vertical = 16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Places button
                    IconButton(
                        onClick = { viewModel.sendPlacesQuery() },
                        modifier = Modifier
                            .size(48.dp)
                            .background(Color(0xFF241408), CircleShape)
                    ) {
                        Icon(
                            imageVector = Icons.Default.LocationOn,
                            contentDescription = "Places",
                            tint = Color(0xFFE87800),
                            modifier = Modifier.size(24.dp)
                        )
                    }

                    // Orb button
                    Box(
                        modifier = Modifier
                            .size(100.dp)
                            .clickable {
                                if (hasAudioPermission) {
                                    viewModel.handleOrbTap()
                                } else {
                                    audioPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                                }
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        OrbView(state = orbState, sizeDp = 100.dp)
                    }

                    // Camera button
                    IconButton(
                        onClick = { imagePickerLauncher.launch("image/*") },
                        modifier = Modifier
                            .size(48.dp)
                            .background(Color(0xFF241408), CircleShape)
                    ) {
                        Icon(
                            imageVector = Icons.Default.CameraAlt,
                            contentDescription = "Camera",
                            tint = Color(0xFFE87800),
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter)
        )
    }
}

@Composable
private fun HomeTopBar(
    onSettingsClick: () -> Unit,
    onHistoryClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onSettingsClick) {
            Icon(
                imageVector = Icons.Default.Settings,
                contentDescription = "Settings",
                tint = Color.White
            )
        }

        Text(
            text = "Max",
            color = Color(0xFFE87800),
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold
        )

        IconButton(onClick = onHistoryClick) {
            Icon(
                imageVector = Icons.Default.History,
                contentDescription = "History",
                tint = Color.White
            )
        }
    }
}

@Composable
private fun EmptyStateContent(
    orbState: OrbState,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        OrbView(state = orbState, sizeDp = 64.dp)
        Spacer(modifier = Modifier.height(20.dp))
        Text(
            text = "Hi! I'm Max",
            color = Color.White,
            fontSize = 24.sp,
            fontWeight = FontWeight.SemiBold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Press the orb to talk to Max",
            color = Color(0xFF8A7A6A),
            fontSize = 15.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
    }
}

@Composable
private fun StatusPill(state: ConversationState) {
    val (color, label) = when (state) {
        ConversationState.LISTENING -> Pair(StatusListening, "Listening...")
        ConversationState.THINKING -> Pair(StatusThinking, "Thinking...")
        ConversationState.SPEAKING -> Pair(StatusSpeaking, "Speaking...")
        ConversationState.IDLE -> Pair(Color.Gray, "Idle")
    }

    Row(
        modifier = Modifier
            .background(Color(0xDD1A1008), RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .background(color, CircleShape)
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(text = label, color = Color.White, fontSize = 13.sp)
    }
}

@Composable
private fun ImagePendingBar(
    onSend: () -> Unit,
    onCancel: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFF241408), RoundedCornerShape(12.dp))
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "Image ready to send",
            color = Color.White,
            fontSize = 14.sp
        )
        Row {
            TextButton(onClick = onCancel) {
                Icon(Icons.Default.Close, contentDescription = "Cancel", tint = Color(0xFF8A7A6A))
            }
            TextButton(onClick = onSend) {
                Icon(Icons.Default.Send, contentDescription = "Send", tint = Color(0xFFE87800))
            }
        }
    }
}

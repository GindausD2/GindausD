package com.max.ai.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.LocalTextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.max.ai.viewmodels.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    onBack: () -> Unit,
    onSignedOut: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(uiState.isSignedOut) {
        if (uiState.isSignedOut) onSignedOut()
    }

    // Saved feedback
    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(uiState.isSaved) {
        if (uiState.isSaved) {
            snackbarHostState.showSnackbar("Settings saved", duration = SnackbarDuration.Short)
        }
    }
    LaunchedEffect(uiState.error) {
        if (uiState.error != null) {
            snackbarHostState.showSnackbar(uiState.error!!, duration = SnackbarDuration.Short)
        }
    }

    // Confirm dialogs state
    var showClearHistoryDialog by remember { mutableStateOf(false) }
    var showSignOutDialog by remember { mutableStateOf(false) }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Settings",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 20.sp
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.White
                )
            )
        },
        containerColor = Color(0xFFF5F5F7)
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // ── API Section ──────────────────────────────────────────────────
            SettingsSection(title = "AI Configuration") {
                SettingsTextField(
                    label = "Claude API Key",
                    value = uiState.apiKey,
                    onValueChange = viewModel::onApiKeyChanged,
                    placeholder = "sk-ant-...",
                    icon = Icons.Default.Lock,
                    isPassword = !uiState.apiKeyVisible,
                    trailingAction = {
                        TextButton(onClick = viewModel::toggleApiKeyVisibility) {
                            Text(
                                text = if (uiState.apiKeyVisible) "Hide" else "Show",
                                color = Color(0xFF7C3AED),
                                fontSize = 13.sp
                            )
                        }
                    }
                )
            }

            // ── Profile Section ───────────────────────────────────────────────
            SettingsSection(title = "Profile") {
                SettingsTextField(
                    label = "Your Name",
                    value = uiState.profileName,
                    onValueChange = viewModel::onProfileNameChanged,
                    placeholder = "Enter your name",
                    icon = Icons.Default.Person
                )
            }

            // ── Preferences Section ───────────────────────────────────────────
            SettingsSection(title = "Preferences") {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Voice Responses",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color(0xFF1A1A2E)
                        )
                        Text(
                            text = "Max will speak responses aloud",
                            fontSize = 13.sp,
                            color = Color(0xFF9CA3AF)
                        )
                    }
                    Switch(
                        checked = uiState.voiceEnabled,
                        onCheckedChange = viewModel::onVoiceToggled,
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = Color.White,
                            checkedTrackColor = Color(0xFF7C3AED)
                        )
                    )
                }
            }

            // ── Save button ───────────────────────────────────────────────────
            Button(
                onClick = viewModel::saveSettings,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF7C3AED),
                    contentColor = Color.White
                )
            ) {
                Text("Save Settings", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            }

            Spacer(Modifier.height(8.dp))

            // ── Danger Zone ───────────────────────────────────────────────────
            SettingsSection(title = "Data") {
                SettingsActionRow(
                    icon = Icons.Default.Delete,
                    title = "Clear Chat History",
                    subtitle = "Remove all conversation messages",
                    iconTint = Color(0xFFEF4444),
                    onClick = { showClearHistoryDialog = true }
                )
                Divider(
                    color = Color(0xFFE5E7EB),
                    modifier = Modifier.padding(vertical = 4.dp)
                )
                SettingsActionRow(
                    icon = Icons.Default.ExitToApp,
                    title = "Sign Out",
                    subtitle = "Return to the welcome screen",
                    iconTint = Color(0xFFEF4444),
                    onClick = { showSignOutDialog = true }
                )
            }
        }
    }

    // ── Clear history confirmation dialog ──────────────────────────────────────
    if (showClearHistoryDialog) {
        AlertDialog(
            onDismissRequest = { showClearHistoryDialog = false },
            title = { Text("Clear Chat History") },
            text = { Text("This will permanently delete all conversation messages. This cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.clearHistory()
                        showClearHistoryDialog = false
                    }
                ) {
                    Text("Clear", color = Color(0xFFEF4444))
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearHistoryDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // ── Sign out confirmation dialog ───────────────────────────────────────────
    if (showSignOutDialog) {
        AlertDialog(
            onDismissRequest = { showSignOutDialog = false },
            title = { Text("Sign Out") },
            text = { Text("Are you sure you want to sign out?") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.signOut()
                    showSignOutDialog = false
                }) {
                    Text("Sign Out", color = Color(0xFFEF4444))
                }
            },
            dismissButton = {
                TextButton(onClick = { showSignOutDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

// ─── Settings section container ───────────────────────────────────────────────

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = title.uppercase(),
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color(0xFF9CA3AF),
            letterSpacing = 0.8.sp,
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp)
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White)
                .padding(16.dp),
            content = content
        )
    }
}

// ─── Text field row ───────────────────────────────────────────────────────────

@Composable
private fun SettingsTextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    icon: ImageVector,
    isPassword: Boolean = false,
    trailingAction: @Composable (() -> Unit)? = null
) {
    Column {
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = Color(0xFF6B7280),
            modifier = Modifier.padding(bottom = 6.dp)
        )
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = {
                Text(
                    text = placeholder,
                    color = Color(0xFFD1D5DB),
                    fontSize = 14.sp
                )
            },
            leadingIcon = {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = Color(0xFF9CA3AF),
                    modifier = Modifier.size(18.dp)
                )
            },
            trailingIcon = trailingAction,
            visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
            keyboardOptions = if (isPassword)
                KeyboardOptions(keyboardType = KeyboardType.Password)
            else
                KeyboardOptions.Default,
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color(0xFF7C3AED),
                unfocusedBorderColor = Color(0xFFE5E7EB),
                cursorColor = Color(0xFF7C3AED)
            ),
            textStyle = LocalTextStyle.current.copy(fontSize = 14.sp)
        )
    }
}

// ─── Action row ───────────────────────────────────────────────────────────────

@Composable
private fun SettingsActionRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    iconTint: Color = Color(0xFF1A1A2E),
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        color = Color.Transparent,
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(iconTint.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconTint,
                    modifier = Modifier.size(18.dp)
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                    color = iconTint
                )
                Text(
                    text = subtitle,
                    fontSize = 12.sp,
                    color = Color(0xFF9CA3AF)
                )
            }
        }
    }
}

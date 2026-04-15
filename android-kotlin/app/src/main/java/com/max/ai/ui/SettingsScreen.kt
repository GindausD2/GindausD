package com.max.ai.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.graphics.Brush
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
    onSignedOut: () -> Unit,
    onThemeChanged: (String) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(uiState.isSignedOut) {
        if (uiState.isSignedOut) onSignedOut()
    }
    LaunchedEffect(uiState.colorScheme) {
        onThemeChanged(uiState.colorScheme)
    }

    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(uiState.isSaved) {
        if (uiState.isSaved) snackbarHostState.showSnackbar("Settings saved", duration = SnackbarDuration.Short)
    }
    LaunchedEffect(uiState.error) {
        if (uiState.error != null) snackbarHostState.showSnackbar(uiState.error!!, duration = SnackbarDuration.Short)
    }

    var showClearHistoryDialog by remember { mutableStateOf(false) }
    var showSignOutDialog       by remember { mutableStateOf(false) }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text("Settings", fontWeight = FontWeight.SemiBold, fontSize = 20.sp) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor    = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                )
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // ── Profile card ──────────────────────────────────────────────────
            ProfileCard(
                name  = uiState.profileName,
                email = uiState.profileEmail
            )

            // ── Appearance ────────────────────────────────────────────────────
            SettingsSection(title = "Appearance") {
                Text(
                    text = "Theme",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 10.dp)
                )
                ThemePicker(
                    selected = uiState.colorScheme,
                    onSelected = { scheme ->
                        viewModel.onColorSchemeChanged(scheme)
                        viewModel.saveSettings()
                    }
                )
            }

            // ── AI Configuration ──────────────────────────────────────────────
            SettingsSection(title = "AI Configuration") {
                SettingsTextField(
                    label = "Anthropic API Key",
                    value = uiState.apiKey,
                    onValueChange = viewModel::onApiKeyChanged,
                    placeholder = "sk-ant-...",
                    icon = Icons.Default.Lock,
                    isPassword = !uiState.apiKeyVisible,
                    trailingAction = {
                        TextButton(onClick = viewModel::toggleApiKeyVisibility) {
                            Text(
                                text = if (uiState.apiKeyVisible) "Hide" else "Show",
                                color = MaterialTheme.colorScheme.primary,
                                fontSize = 13.sp
                            )
                        }
                    }
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "Stored locally · only sent to Anthropic's API",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // ── Profile ───────────────────────────────────────────────────────
            SettingsSection(title = "Profile") {
                SettingsTextField(
                    label = "Your Name",
                    value = uiState.profileName,
                    onValueChange = viewModel::onProfileNameChanged,
                    placeholder = "Enter your name",
                    icon = Icons.Default.Person
                )
            }

            // ── Preferences ───────────────────────────────────────────────────
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
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Max speaks responses aloud",
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Switch(
                        checked = uiState.voiceEnabled,
                        onCheckedChange = viewModel::onVoiceToggled,
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = Color.White,
                            checkedTrackColor = MaterialTheme.colorScheme.primary
                        )
                    )
                }
            }

            // ── Save button ───────────────────────────────────────────────────
            Button(
                onClick = viewModel::saveSettings,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor   = MaterialTheme.colorScheme.onPrimary
                )
            ) {
                Text("Save Settings", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            }

            // ── Data / Danger zone ────────────────────────────────────────────
            SettingsSection(title = "Data") {
                SettingsActionRow(
                    icon     = Icons.Default.Delete,
                    title    = "Clear Chat History",
                    subtitle = "Remove all conversation messages",
                    iconTint = Color(0xFFEF4444),
                    onClick  = { showClearHistoryDialog = true }
                )
                HorizontalDivider(
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                    modifier = Modifier.padding(vertical = 4.dp)
                )
                SettingsActionRow(
                    icon     = Icons.Default.ExitToApp,
                    title    = "Sign Out",
                    subtitle = "Return to the welcome screen",
                    iconTint = Color(0xFFEF4444),
                    onClick  = { showSignOutDialog = true }
                )
            }

            // ── About ─────────────────────────────────────────────────────────
            SettingsSection(title = "About") {
                SettingsInfoRow(label = "Version",  value = "1.0.0")
                HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))
                SettingsInfoRow(label = "Model",    value = "Claude Sonnet 4.6")
                HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))
                SettingsInfoRow(label = "Platform", value = "Android")
            }

            Spacer(Modifier.height(16.dp))
        }
    }

    // ── Dialogs ───────────────────────────────────────────────────────────────

    if (showClearHistoryDialog) {
        AlertDialog(
            onDismissRequest = { showClearHistoryDialog = false },
            title   = { Text("Clear Chat History") },
            text    = { Text("This will permanently delete all conversation messages. This cannot be undone.") },
            confirmButton = {
                TextButton(onClick = { viewModel.clearHistory(); showClearHistoryDialog = false }) {
                    Text("Clear", color = Color(0xFFEF4444))
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearHistoryDialog = false }) { Text("Cancel") }
            }
        )
    }

    if (showSignOutDialog) {
        AlertDialog(
            onDismissRequest = { showSignOutDialog = false },
            title   = { Text("Sign Out") },
            text    = { Text("Are you sure you want to sign out?") },
            confirmButton = {
                TextButton(onClick = { viewModel.signOut(); showSignOutDialog = false }) {
                    Text("Sign Out", color = Color(0xFFEF4444))
                }
            },
            dismissButton = {
                TextButton(onClick = { showSignOutDialog = false }) { Text("Cancel") }
            }
        )
    }
}

// ─── Profile card ─────────────────────────────────────────────────────────────

@Composable
private fun ProfileCard(name: String, email: String) {
    val initials = buildInitials(name.ifBlank { email })
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier.padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Avatar circle
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            colors = listOf(Color(0xFF8B21F0), Color(0xFF4F1FDE))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = initials,
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                if (name.isNotBlank()) {
                    Text(
                        text = name,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
                if (email.isNotBlank()) {
                    Text(
                        text = email,
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

private fun buildInitials(displayName: String): String {
    val parts = displayName.trim().split(" ").filter { it.isNotBlank() }
    return when {
        parts.size >= 2 -> "${parts[0].first()}${parts[1].first()}".uppercase()
        parts.size == 1 -> parts[0].take(2).uppercase()
        else            -> "M"
    }
}

// ─── Theme picker (System / Light / Dark segmented) ──────────────────────────

@Composable
private fun ThemePicker(
    selected: String,
    onSelected: (String) -> Unit
) {
    val options = listOf("system" to "System", "light" to "Light", "dark" to "Dark")
    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
        options.forEachIndexed { index, (value, label) ->
            SegmentedButton(
                selected = selected == value,
                onClick  = { onSelected(value) },
                shape    = SegmentedButtonDefaults.itemShape(index = index, count = options.size),
                colors   = SegmentedButtonDefaults.colors(
                    activeContainerColor  = MaterialTheme.colorScheme.primary,
                    activeContentColor    = MaterialTheme.colorScheme.onPrimary
                )
            ) {
                Text(label, fontSize = 13.sp, fontWeight = FontWeight.Medium)
            }
        }
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
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            letterSpacing = 0.8.sp,
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp)
        )
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp), content = content)
        }
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
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 6.dp)
        )
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = {
                Text(text = placeholder, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f), fontSize = 14.sp)
            },
            leadingIcon = {
                Icon(imageVector = icon, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(18.dp))
            },
            trailingIcon = trailingAction,
            visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
            keyboardOptions = if (isPassword) KeyboardOptions(keyboardType = KeyboardType.Password) else KeyboardOptions.Default,
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor   = MaterialTheme.colorScheme.primary,
                unfocusedBorderColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.20f),
                cursorColor          = MaterialTheme.colorScheme.primary
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
    iconTint: Color = MaterialTheme.colorScheme.onSurface,
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
                    .background(iconTint.copy(alpha = 0.10f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(imageVector = icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(18.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(text = title,    fontSize = 15.sp, fontWeight = FontWeight.Medium, color = iconTint)
                Text(text = subtitle, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(
                imageVector = Icons.Default.ArrowBack,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

@Composable
private fun SettingsInfoRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(text = label, fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface)
        Text(text = value, fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

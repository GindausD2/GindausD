package com.gindausd.max.ui

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.RecordVoiceOver
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gindausd.max.AppSettings
import com.gindausd.max.data.AuthRepository
import com.gindausd.max.data.StorageRepository
import com.gindausd.max.services.BriefingService
import com.gindausd.max.ui.theme.BackgroundDark
import com.gindausd.max.ui.theme.OrangePrimary
import com.gindausd.max.ui.theme.SurfaceDark
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun SettingsScreen(
    onNavigateBack: () -> Unit,
    onSignOut: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val authRepo = remember { AuthRepository.getInstance(context) }
    val storageRepo = remember { StorageRepository.getInstance(context) }
    val currentUser by authRepo.currentUser.collectAsState()

    var settings by remember { mutableStateOf(AppSettings()) }
    var showBriefingDialog by remember { mutableStateOf(false) }
    var showSignOutDialog by remember { mutableStateOf(false) }
    var showClearDialog by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        settings = withContext(Dispatchers.IO) { storageRepo.loadSettings() }
    }

    fun saveSettings(newSettings: AppSettings) {
        settings = newSettings
        scope.launch(Dispatchers.IO) { storageRepo.saveSettings(newSettings) }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(BackgroundDark)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        ) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = Color.White
                    )
                }
                Text(
                    text = "Settings",
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            // Profile header
            ProfileHeader(
                name = currentUser?.name ?: "Max User",
                email = currentUser?.email ?: "",
                isDemo = currentUser?.isDemo == true,
                daysRemaining = authRepo.demoTrialDaysRemaining
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Quick actions section
            SectionHeader("QUICK ACTIONS")
            SettingsRow(icon = Icons.Default.Star, label = "Subscription", onClick = {})
            SettingsRow(icon = Icons.Default.Memory, label = "Memory", onClick = {})
            SettingsRow(icon = Icons.Default.Lock, label = "Privacy", onClick = {})

            Spacer(modifier = Modifier.height(16.dp))

            // Configuration section
            SectionHeader("CONFIGURATION")
            SettingsToggleRow(
                icon = Icons.Default.Schedule,
                label = "Morning Briefing",
                checked = settings.briefingEnabled,
                onCheckedChange = { enabled ->
                    saveSettings(settings.copy(briefingEnabled = enabled))
                    if (enabled) {
                        BriefingService.scheduleDailyBriefing(context, settings.briefingHour, settings.briefingMinute)
                    } else {
                        BriefingService.cancelBriefing(context)
                    }
                },
                trailingContent = {
                    if (settings.briefingEnabled) {
                        TextButton(onClick = { showBriefingDialog = true }) {
                            Text(
                                text = String.format("%02d:%02d", settings.briefingHour, settings.briefingMinute),
                                color = OrangePrimary,
                                fontSize = 14.sp
                            )
                        }
                    }
                }
            )
            SettingsToggleRow(
                icon = Icons.Default.RecordVoiceOver,
                label = "Voice Response",
                checked = settings.voiceEnabled,
                onCheckedChange = { saveSettings(settings.copy(voiceEnabled = it)) }
            )
            SettingsRow(
                icon = Icons.Default.RecordVoiceOver,
                label = "Voice: ${settings.preferredVoice.replaceFirstChar { it.uppercase() }}",
                onClick = {
                    val next = if (settings.preferredVoice == "female") "male" else "female"
                    saveSettings(settings.copy(preferredVoice = next))
                }
            )

            Spacer(modifier = Modifier.height(16.dp))

            // About section
            SectionHeader("ABOUT")
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Version", color = Color(0xFF8A7A6A), fontSize = 15.sp)
                Text("1.0.0", color = Color.White, fontSize = 15.sp)
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Clear history
            DangerButton(
                label = "Clear Conversation History",
                icon = Icons.Default.Delete,
                onClick = { showClearDialog = true }
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Sign out
            DangerButton(
                label = "Sign Out",
                icon = Icons.Default.ExitToApp,
                onClick = { showSignOutDialog = true }
            )

            Spacer(modifier = Modifier.height(40.dp))
        }
    }

    if (showBriefingDialog) {
        BriefingTimeDialog(
            hour = settings.briefingHour,
            minute = settings.briefingMinute,
            onConfirm = { h, m ->
                saveSettings(settings.copy(briefingHour = h, briefingMinute = m))
                if (settings.briefingEnabled) {
                    BriefingService.scheduleDailyBriefing(context, h, m)
                }
                showBriefingDialog = false
            },
            onDismiss = { showBriefingDialog = false }
        )
    }

    if (showSignOutDialog) {
        ConfirmDialog(
            title = "Sign Out",
            message = "Are you sure you want to sign out?",
            confirmText = "Sign Out",
            onConfirm = {
                scope.launch {
                    authRepo.signOut()
                    onSignOut()
                }
            },
            onDismiss = { showSignOutDialog = false }
        )
    }

    if (showClearDialog) {
        ConfirmDialog(
            title = "Clear History",
            message = "This will permanently delete all conversation history. This cannot be undone.",
            confirmText = "Clear",
            onConfirm = {
                scope.launch(Dispatchers.IO) { storageRepo.saveMessages(emptyList()) }
                showClearDialog = false
            },
            onDismiss = { showClearDialog = false }
        )
    }
}

@Composable
private fun ProfileHeader(
    name: String,
    email: String,
    isDemo: Boolean,
    daysRemaining: Int
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .background(SurfaceDark, RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(60.dp)
                .background(OrangePrimary.copy(alpha = 0.2f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.AccountCircle,
                contentDescription = null,
                tint = OrangePrimary,
                modifier = Modifier.size(40.dp)
            )
        }

        Spacer(modifier = Modifier.width(14.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(text = name, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            if (email.isNotBlank()) {
                Text(text = email, color = Color(0xFF8A7A6A), fontSize = 13.sp)
            }
        }

        if (isDemo) {
            Box(
                modifier = Modifier
                    .background(OrangePrimary.copy(alpha = 0.15f), RoundedCornerShape(8.dp))
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text(
                    text = "$daysRemaining days left",
                    color = OrangePrimary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        } else {
            Box(
                modifier = Modifier
                    .background(Color(0xFF1F3A1A), RoundedCornerShape(8.dp))
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text(
                    text = "Pro",
                    color = Color(0xFF43A047),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        color = Color(0xFF8A7A6A),
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
    )
}

@Composable
private fun SettingsRow(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = OrangePrimary, modifier = Modifier.size(22.dp))
        Spacer(modifier = Modifier.width(14.dp))
        Text(text = label, color = Color.White, fontSize = 15.sp, modifier = Modifier.weight(1f))
        Icon(imageVector = Icons.Default.ChevronRight, contentDescription = null, tint = Color(0xFF5C4A30))
    }
}

@Composable
private fun SettingsToggleRow(
    icon: ImageVector,
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    trailingContent: @Composable () -> Unit = {}
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = OrangePrimary, modifier = Modifier.size(22.dp))
        Spacer(modifier = Modifier.width(14.dp))
        Text(text = label, color = Color.White, fontSize = 15.sp, modifier = Modifier.weight(1f))
        trailingContent()
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = OrangePrimary,
                uncheckedThumbColor = Color.White,
                uncheckedTrackColor = Color(0xFF3D2E18)
            )
        )
    }
}

@Composable
private fun DangerButton(label: String, icon: ImageVector, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .background(Color(0xFF2A0808), RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = Color(0xFFE53935), modifier = Modifier.size(22.dp))
        Spacer(modifier = Modifier.width(14.dp))
        Text(text = label, color = Color(0xFFE53935), fontSize = 15.sp)
    }
}

@Composable
private fun BriefingTimeDialog(
    hour: Int,
    minute: Int,
    onConfirm: (Int, Int) -> Unit,
    onDismiss: () -> Unit
) {
    var selectedHour by remember { mutableIntStateOf(hour) }
    var selectedMinute by remember { mutableIntStateOf(minute) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1A1008),
        title = { Text("Briefing Time", color = Color.White, fontWeight = FontWeight.Bold) },
        text = {
            Column {
                Text("Set your daily morning briefing time:", color = Color(0xFF8A7A6A), fontSize = 14.sp)
                Spacer(modifier = Modifier.height(16.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Hour picker (simple +/- for now)
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        TextButton(onClick = { selectedHour = (selectedHour + 1) % 24 }) {
                            Text("+", color = OrangePrimary, fontSize = 20.sp)
                        }
                        Text(
                            text = String.format("%02d", selectedHour),
                            color = Color.White,
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold
                        )
                        TextButton(onClick = { selectedHour = if (selectedHour == 0) 23 else selectedHour - 1 }) {
                            Text("-", color = OrangePrimary, fontSize = 20.sp)
                        }
                    }
                    Text(":", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        TextButton(onClick = { selectedMinute = (selectedMinute + 5) % 60 }) {
                            Text("+", color = OrangePrimary, fontSize = 20.sp)
                        }
                        Text(
                            text = String.format("%02d", selectedMinute),
                            color = Color.White,
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold
                        )
                        TextButton(onClick = { selectedMinute = if (selectedMinute < 5) 55 else selectedMinute - 5 }) {
                            Text("-", color = OrangePrimary, fontSize = 20.sp)
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { onConfirm(selectedHour, selectedMinute) },
                colors = ButtonDefaults.buttonColors(containerColor = OrangePrimary)
            ) { Text("Set") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = Color(0xFF8A7A6A))
            }
        }
    )
}

@Composable
private fun ConfirmDialog(
    title: String,
    message: String,
    confirmText: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1A1008),
        title = { Text(title, color = Color.White, fontWeight = FontWeight.Bold) },
        text = { Text(message, color = Color(0xFF8A7A6A), fontSize = 14.sp) },
        confirmButton = {
            Button(
                onClick = onConfirm,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE53935))
            ) { Text(confirmText) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = Color(0xFF8A7A6A))
            }
        }
    )
}

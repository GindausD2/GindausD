package com.max.ai

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.max.ai.services.*
import com.max.ai.ui.HomeScreen
import com.max.ai.ui.SettingsScreen
import com.max.ai.ui.WelcomeScreen
import com.max.ai.ui.theme.MaxAITheme
import com.max.ai.viewmodels.HomeViewModel
import com.max.ai.viewmodels.SettingsViewModel
import com.max.ai.viewmodels.WelcomeViewModel

class MainActivity : ComponentActivity() {

    private val app: MaxApplication by lazy { application as MaxApplication }

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { /* Results handled gracefully inside features */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)

        requestAppPermissions()

        setContent {
            AppRoot(
                authRepository    = app.authRepository,
                storageRepository = app.storageRepository,
                claudeService     = app.claudeService,
                voiceService      = app.voiceService,
                toolsService      = app.toolsService,
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    private fun requestAppPermissions() {
        val permissions = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        permissionLauncher.launch(permissions.toTypedArray())
    }
}

// ─── Root navigation ──────────────────────────────────────────────────────────

enum class Screen { LOADING, WELCOME, HOME, SETTINGS }

@Composable
fun AppRoot(
    authRepository: AuthRepository,
    storageRepository: StorageRepository,
    claudeService: ClaudeService,
    voiceService: VoiceService,
    toolsService: ToolsService,
) {
    var currentScreen by remember { mutableStateOf(Screen.LOADING) }

    // Read persisted color scheme preference
    val storedScheme = remember { storageRepository.getSettings().colorScheme }
    val systemIsDark = isSystemInDarkTheme()
    var themeString by remember {
        mutableStateOf(storedScheme)
    }

    val useDarkTheme = when (themeString) {
        "light"  -> false
        "dark"   -> true
        else     -> systemIsDark  // "system"
    }

    MaxAITheme(useDarkTheme = useDarkTheme) {
        Surface(modifier = Modifier.fillMaxSize(), color = Color.Transparent) {

            LaunchedEffect(Unit) {
                currentScreen = if (authRepository.getUser() != null) Screen.HOME else Screen.WELCOME
            }

            Crossfade(targetState = currentScreen, label = "nav") { screen ->
                when (screen) {
                    Screen.LOADING -> {
                        Surface(modifier = Modifier.fillMaxSize(), color = Color(0xFF2D1B69)) {}
                    }

                    Screen.WELCOME -> {
                        val vm = remember { WelcomeViewModel(authRepository) }
                        WelcomeScreen(
                            viewModel       = vm,
                            onAuthenticated = { currentScreen = Screen.HOME },
                        )
                    }

                    Screen.HOME -> {
                        val vm = remember {
                            HomeViewModel(
                                authRepository    = authRepository,
                                storageRepository = storageRepository,
                                claudeService     = claudeService,
                                voiceService      = voiceService,
                                toolsService      = toolsService,
                            )
                        }
                        HomeScreen(
                            viewModel            = vm,
                            onNavigateToSettings = { currentScreen = Screen.SETTINGS },
                        )
                    }

                    Screen.SETTINGS -> {
                        val vm = remember { SettingsViewModel(storageRepository, authRepository) }
                        SettingsScreen(
                            viewModel        = vm,
                            onBack           = { currentScreen = Screen.HOME },
                            onSignedOut      = { currentScreen = Screen.WELCOME },
                            onThemeChanged   = { themeString = it }
                        )
                    }
                }
            }
        }
    }
}

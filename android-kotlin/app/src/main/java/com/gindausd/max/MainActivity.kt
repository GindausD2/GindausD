package com.gindausd.max

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.gindausd.max.data.AuthRepository
import com.gindausd.max.ui.theme.MaxTheme
import com.gindausd.max.ui.ConversationHistoryScreen
import com.gindausd.max.ui.HomeScreen
import com.gindausd.max.ui.MemoryScreen
import com.gindausd.max.ui.OnboardingScreen
import com.gindausd.max.ui.PaywallScreen
import com.gindausd.max.ui.SettingsScreen
import com.gindausd.max.ui.WelcomeScreen

class MainActivity : ComponentActivity() {

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == "com.gindausd.max.START_LISTENING") {
            AppEvents.emitStartListening()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle cold-start from widget or tile
        if (intent?.action == "com.gindausd.max.START_LISTENING") {
            AppEvents.emitStartListening()
        }
        setContent {
            MaxTheme {
                val navController = rememberNavController()
                val authRepo = remember { AuthRepository.getInstance(applicationContext) }
                var startDestination by remember { mutableStateOf("welcome") }

                LaunchedEffect(Unit) {
                    authRepo.expireDemoIfNeeded()
                    val user = authRepo.currentUser.value
                    startDestination = when {
                        user != null && (user.isDemo == false || user.isDemo == null) -> "home"
                        user != null && user.isDemo == true && !authRepo.isDemoExpired -> "home"
                        else -> "welcome"
                    }
                }

                NavHost(
                    navController = navController,
                    startDestination = startDestination
                ) {
                    composable("welcome") {
                        WelcomeScreen(
                            onNavigateToHome = { navController.navigate("home") { popUpTo("welcome") { inclusive = true } } },
                            onNavigateToOnboarding = { navController.navigate("onboarding") { popUpTo("welcome") { inclusive = true } } }
                        )
                    }
                    composable("onboarding") {
                        OnboardingScreen(
                            onComplete = { navController.navigate("home") { popUpTo("onboarding") { inclusive = true } } }
                        )
                    }
                    composable("home") {
                        HomeScreen(
                            onNavigateToSettings = { navController.navigate("settings") },
                            onNavigateToHistory = { navController.navigate("history") }
                        )
                    }
                    composable("settings") {
                        SettingsScreen(
                            onNavigateBack = { navController.popBackStack() },
                            onSignOut = {
                                navController.navigate("welcome") { popUpTo(0) { inclusive = true } }
                            },
                            onNavigateToMemory = { navController.navigate("memory") }
                        )
                    }
                    composable("history") {
                        ConversationHistoryScreen(
                            onNavigateBack = { navController.popBackStack() }
                        )
                    }
                    composable("memory") {
                        MemoryScreen(onNavigateBack = { navController.popBackStack() })
                    }
                    composable("paywall") {
                        PaywallScreen(
                            onNavigateBack = { navController.popBackStack() },
                            onSubscribed = { navController.navigate("home") { popUpTo("paywall") { inclusive = true } } }
                        )
                    }
                }
            }
        }
    }
}

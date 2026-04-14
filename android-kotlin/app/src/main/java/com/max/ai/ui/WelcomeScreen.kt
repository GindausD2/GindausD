package com.max.ai.ui

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import com.max.ai.R
import com.google.accompanist.pager.*
import com.max.ai.OrbState
import com.max.ai.ui.components.*
import com.max.ai.ui.theme.WelcomeGradientColors
import com.max.ai.viewmodels.WelcomeViewModel
import kotlinx.coroutines.launch

@OptIn(ExperimentalPagerApi::class)
@Composable
fun WelcomeScreen(
    viewModel: WelcomeViewModel,
    onAuthenticated: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val pagerState = rememberPagerState(initialPage = 1)
    val scope = rememberCoroutineScope()

    // Navigate to home when authenticated
    LaunchedEffect(uiState.isAuthenticated) {
        if (uiState.isAuthenticated) onAuthenticated()
    }

    // Sync pager with viewmodel page
    LaunchedEffect(uiState.currentPage) {
        if (pagerState.currentPage != uiState.currentPage) {
            pagerState.animateScrollToPage(uiState.currentPage)
        }
    }

    LaunchedEffect(pagerState.currentPage) {
        viewModel.navigateToPage(pagerState.currentPage)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(colors = WelcomeGradientColors)
            )
    ) {
        // Page indicator dots at top
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 52.dp),
            contentAlignment = Alignment.TopCenter
        ) {
            HorizontalPagerIndicator(
                pagerState = pagerState,
                activeColor = Color.White,
                inactiveColor = Color.White.copy(alpha = 0.35f),
                indicatorWidth = 8.dp,
                indicatorHeight = 8.dp,
                spacing = 6.dp
            )
        }

        // Pager
        HorizontalPager(
            count = 3,
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            when (page) {
                0 -> LoginPage(
                    uiState = uiState,
                    onEmailChanged = viewModel::onEmailChanged,
                    onPasswordChanged = viewModel::onPasswordChanged,
                    onLogin = viewModel::login,
                    onNavigateToSignUp = {
                        scope.launch { pagerState.animateScrollToPage(2) }
                    }
                )
                1 -> WelcomeCenterPage(
                    uiState = uiState,
                    onNavigateToLogin = {
                        scope.launch { pagerState.animateScrollToPage(0) }
                    },
                    onGetStarted = {
                        scope.launch { pagerState.animateScrollToPage(2) }
                    },
                    onTryDemo = viewModel::startDemo
                )
                2 -> SignUpPage(
                    uiState = uiState,
                    onSignUpNameChanged = viewModel::onSignUpNameChanged,
                    onSignUpEmailChanged = viewModel::onSignUpEmailChanged,
                    onSignUpPasswordChanged = viewModel::onSignUpPasswordChanged,
                    onToggleEmailExpand = viewModel::toggleEmailSignUp,
                    onSignUpWithEmail = viewModel::signUpWithEmail,
                    onSignUpWithGoogle = viewModel::signUpWithGoogle,
                    onNavigateToLogin = {
                        scope.launch { pagerState.animateScrollToPage(0) }
                    }
                )
            }
        }

        // Global error snackbar
        if (uiState.error != null) {
            Snackbar(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(16.dp),
                containerColor = Color(0xFFB00020),
                contentColor = Color.White
            ) {
                Text(uiState.error!!)
            }
        }
    }
}

// ─── Page 0: Login ────────────────────────────────────────────────────────────

@Composable
private fun LoginPage(
    uiState: com.max.ai.viewmodels.WelcomeUiState,
    onEmailChanged: (String) -> Unit,
    onPasswordChanged: (String) -> Unit,
    onLogin: () -> Unit,
    onNavigateToSignUp: () -> Unit
) {
    val focusManager = LocalFocusManager.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Spacer(Modifier.height(80.dp))

        Text(
            text = "Welcome back",
            color = Color.White,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )

        Text(
            text = "Sign in to Max AI",
            color = Color.White.copy(alpha = 0.7f),
            fontSize = 16.sp,
            modifier = Modifier.padding(top = 6.dp, bottom = 32.dp)
        )

        GlassCard(modifier = Modifier.fillMaxWidth()) {
            GlassTextField(
                value = uiState.email,
                onValueChange = onEmailChanged,
                placeholder = "Email",
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Email,
                    imeAction = ImeAction.Next
                ),
                keyboardActions = KeyboardActions(
                    onNext = { focusManager.moveFocus(FocusDirection.Down) }
                )
            )

            Spacer(Modifier.height(14.dp))

            GlassTextField(
                value = uiState.password,
                onValueChange = onPasswordChanged,
                placeholder = "Password",
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done
                ),
                keyboardActions = KeyboardActions(onDone = { onLogin() })
            )

            Spacer(Modifier.height(20.dp))

            GlassButton(
                text = "Login",
                onClick = onLogin,
                isLoading = uiState.isLoading
            )
        }

        Spacer(Modifier.height(24.dp))

        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Don't have an account?",
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 14.sp
            )
            Spacer(Modifier.width(6.dp))
            Text(
                text = "Sign up →",
                color = Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable(onClick = onNavigateToSignUp)
            )
        }

        Spacer(Modifier.height(80.dp))
    }
}

// ─── Page 1: Welcome Center ───────────────────────────────────────────────────

@Composable
private fun WelcomeCenterPage(
    uiState: com.max.ai.viewmodels.WelcomeUiState,
    onNavigateToLogin: () -> Unit,
    onGetStarted: () -> Unit,
    onTryDemo: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Animated Orb
        OrbComponent(
            state = OrbState.IDLE,
            size = 140.dp
        )

        Spacer(Modifier.height(32.dp))

        // Title glass card
        GlassCard(
            modifier = Modifier.fillMaxWidth(),
            alpha = 0.15f
        ) {
            Image(
                painter = painterResource(id = R.drawable.ic_max_logo),
                contentDescription = "Max AI logo",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(80.dp)
                    .padding(bottom = 6.dp),
                colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(Color.White)
            )
            Text(
                text = "Your AI Personal Assistant",
                color = Color.White.copy(alpha = 0.8f),
                fontSize = 16.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 6.dp)
            )
        }

        Spacer(Modifier.height(36.dp))

        // Navigation pills
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            GlassPillButton(
                text = "← Login",
                onClick = onNavigateToLogin,
                modifier = Modifier.weight(1f).padding(end = 8.dp)
            )
            GlassPillButton(
                text = "Get started →",
                onClick = onGetStarted,
                modifier = Modifier.weight(1f).padding(start = 8.dp)
            )
        }

        Spacer(Modifier.height(18.dp))

        // Try Demo
        TextButton(
            onClick = onTryDemo,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                text = "Try Demo",
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

// ─── Page 2: Sign Up ─────────────────────────────────────────────────────────

@Composable
private fun SignUpPage(
    uiState: com.max.ai.viewmodels.WelcomeUiState,
    onSignUpNameChanged: (String) -> Unit,
    onSignUpEmailChanged: (String) -> Unit,
    onSignUpPasswordChanged: (String) -> Unit,
    onToggleEmailExpand: () -> Unit,
    onSignUpWithEmail: () -> Unit,
    onSignUpWithGoogle: () -> Unit,
    onNavigateToLogin: () -> Unit
) {
    val focusManager = LocalFocusManager.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Spacer(Modifier.height(80.dp))

        Text(
            text = "Create account",
            color = Color.White,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
        Text(
            text = "Get started with Max AI",
            color = Color.White.copy(alpha = 0.7f),
            fontSize = 16.sp,
            modifier = Modifier.padding(top = 6.dp, bottom = 32.dp)
        )

        GlassCard(modifier = Modifier.fillMaxWidth()) {
            // Google sign-in button
            GlassButton(
                text = "Continue with Google",
                onClick = onSignUpWithGoogle,
                isLoading = uiState.isLoading && !uiState.isEmailSignUpExpanded
            )

            Spacer(Modifier.height(12.dp))

            // Divider
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Divider(
                    modifier = Modifier.weight(1f),
                    color = Color.White.copy(alpha = 0.25f)
                )
                Text(
                    text = "  or  ",
                    color = Color.White.copy(alpha = 0.5f),
                    fontSize = 13.sp
                )
                Divider(
                    modifier = Modifier.weight(1f),
                    color = Color.White.copy(alpha = 0.25f)
                )
            }

            Spacer(Modifier.height(12.dp))

            // Email sign-up toggle button
            val emailToggleShape = RoundedCornerShape(16.dp)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .clip(emailToggleShape)
                    .background(Color.White.copy(alpha = 0.10f))
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(Color.White.copy(alpha = 0.16f), Color.Transparent),
                            endY = 60f
                        )
                    )
                    .border(
                        1.dp,
                        Brush.linearGradient(
                            colors = listOf(
                                Color.White.copy(alpha = 0.45f),
                                Color.White.copy(alpha = 0.08f)
                            )
                        ),
                        emailToggleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                OutlinedButton(
                    onClick = onToggleEmailExpand,
                    modifier = Modifier.fillMaxSize(),
                    shape = emailToggleShape,
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = Color.White,
                        containerColor = Color.Transparent
                    ),
                    border = null
                ) {
                    Icon(
                        imageVector = Icons.Default.Email,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = if (uiState.isEmailSignUpExpanded) "Use email ▲" else "Continue with Email ▼",
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // Inline email form
            AnimatedVisibility(
                visible = uiState.isEmailSignUpExpanded,
                enter = expandVertically() + fadeIn(),
                exit = shrinkVertically() + fadeOut()
            ) {
                Column(modifier = Modifier.padding(top = 14.dp)) {
                    GlassTextField(
                        value = uiState.signUpName,
                        onValueChange = onSignUpNameChanged,
                        placeholder = "Full name",
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Text,
                            imeAction = ImeAction.Next
                        ),
                        keyboardActions = KeyboardActions(
                            onNext = { focusManager.moveFocus(FocusDirection.Down) }
                        )
                    )
                    Spacer(Modifier.height(10.dp))
                    GlassTextField(
                        value = uiState.signUpEmail,
                        onValueChange = onSignUpEmailChanged,
                        placeholder = "Email",
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Email,
                            imeAction = ImeAction.Next
                        ),
                        keyboardActions = KeyboardActions(
                            onNext = { focusManager.moveFocus(FocusDirection.Down) }
                        )
                    )
                    Spacer(Modifier.height(10.dp))
                    GlassTextField(
                        value = uiState.signUpPassword,
                        onValueChange = onSignUpPasswordChanged,
                        placeholder = "Password",
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Password,
                            imeAction = ImeAction.Done
                        ),
                        keyboardActions = KeyboardActions(onDone = { onSignUpWithEmail() })
                    )
                    Spacer(Modifier.height(16.dp))
                    GlassButton(
                        text = "Create Account",
                        onClick = onSignUpWithEmail,
                        isLoading = uiState.isLoading
                    )
                }
            }
        }

        Spacer(Modifier.height(24.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "Already have an account?",
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 14.sp
            )
            Spacer(Modifier.width(6.dp))
            Text(
                text = "Sign in",
                color = Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable(onClick = onNavigateToLogin)
            )
        }

        Spacer(Modifier.height(80.dp))
    }
}

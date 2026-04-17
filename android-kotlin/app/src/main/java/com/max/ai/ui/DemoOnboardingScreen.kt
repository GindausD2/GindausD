package com.max.ai.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.RecordVoiceOver
import androidx.compose.material.icons.filled.VoiceChat
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.accompanist.pager.ExperimentalPagerApi
import com.google.accompanist.pager.HorizontalPager
import com.google.accompanist.pager.HorizontalPagerIndicator
import com.google.accompanist.pager.rememberPagerState
import com.max.ai.ui.theme.WelcomeGradientColors
import com.max.ai.viewmodels.WelcomeUiState
import kotlinx.coroutines.launch

private val Violet = Color(0xFF7C3AED)
private val VioletLight = Color(0xFFA78BFA)

@OptIn(ExperimentalPagerApi::class)
@Composable
fun DemoOnboardingScreen(
    uiState: WelcomeUiState,
    onNameChanged: (String) -> Unit,
    onGenderChanged: (String) -> Unit,
    onVoiceChanged: (String) -> Unit,
    onFinish: () -> Unit,
    onDismiss: () -> Unit
) {
    val pagerState = rememberPagerState(initialPage = 0)
    val scope = rememberCoroutineScope()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.linearGradient(colors = WelcomeGradientColors))
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = {
                    if (pagerState.currentPage == 0) onDismiss()
                    else scope.launch { pagerState.animateScrollToPage(pagerState.currentPage - 1) }
                }) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
                }
                Spacer(Modifier.weight(1f))
                HorizontalPagerIndicator(
                    pagerState = pagerState,
                    activeColor = Color.White,
                    inactiveColor = Color.White.copy(alpha = 0.35f),
                    indicatorWidth = 8.dp,
                    indicatorHeight = 8.dp,
                    spacing = 6.dp,
                    modifier = Modifier.padding(end = 48.dp)
                )
            }

            HorizontalPager(
                count = 3,
                state = pagerState,
                modifier = Modifier.weight(1f)
            ) { page ->
                when (page) {
                    0 -> DemoSlide1(
                        name = uiState.demoName,
                        gender = uiState.demoGender,
                        onNameChanged = onNameChanged,
                        onGenderChanged = onGenderChanged,
                        onNext = { scope.launch { pagerState.animateScrollToPage(1) } }
                    )
                    1 -> DemoSlide2(
                        voice = uiState.demoVoice,
                        onVoiceChanged = onVoiceChanged,
                        onNext = { scope.launch { pagerState.animateScrollToPage(2) } }
                    )
                    2 -> DemoSlide3(
                        name = uiState.demoName,
                        gender = uiState.demoGender,
                        voice = uiState.demoVoice,
                        isLoading = uiState.isLoading,
                        onLaunch = onFinish
                    )
                }
            }
        }
    }
}

// ─── Slide 1: Name + Gender ───────────────────────────────────────────────────

@Composable
private fun DemoSlide1(
    name: String,
    gender: String,
    onNameChanged: (String) -> Unit,
    onGenderChanged: (String) -> Unit,
    onNext: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Spacer(Modifier.height(24.dp))

        Text("Let's get to know you", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Text("Tell Max a bit about yourself", color = Color.White.copy(alpha = 0.65f), fontSize = 15.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(36.dp))

        // Name field
        OutlinedTextField(
            value = name,
            onValueChange = onNameChanged,
            label = { Text("Your name", color = Color.White.copy(alpha = 0.70f)) },
            placeholder = { Text("e.g. Alex", color = Color.White.copy(alpha = 0.35f)) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor       = Color.White,
                unfocusedTextColor     = Color.White,
                focusedBorderColor     = VioletLight,
                unfocusedBorderColor   = Color.White.copy(alpha = 0.30f),
                cursorColor            = VioletLight,
                focusedContainerColor  = Color.White.copy(alpha = 0.05f),
                unfocusedContainerColor= Color.White.copy(alpha = 0.05f)
            ),
            shape = RoundedCornerShape(16.dp),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words)
        )

        Spacer(Modifier.height(28.dp))

        Text("Gender", color = Color.White.copy(alpha = 0.80f), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(12.dp))

        // Gender chips
        listOf(
            "male" to "Male",
            "female" to "Female",
            "prefer_not_to_say" to "Prefer not to say"
        ).forEach { (value, label) ->
            val selected = gender == value
            val borderColor by animateColorAsState(if (selected) Violet else Color.White.copy(alpha = 0.25f), label = "border")
            val bgColor by animateColorAsState(if (selected) Violet.copy(alpha = 0.20f) else Color.White.copy(alpha = 0.06f), label = "bg")

            OutlinedButton(
                onClick = { onGenderChanged(value) },
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).height(50.dp),
                shape = RoundedCornerShape(14.dp),
                border = BorderStroke(1.5.dp, borderColor),
                colors = ButtonDefaults.outlinedButtonColors(containerColor = bgColor, contentColor = Color.White)
            ) {
                Text(label, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal)
                if (selected) {
                    Spacer(Modifier.weight(1f))
                    Icon(Icons.Default.Check, contentDescription = null, tint = VioletLight, modifier = Modifier.size(18.dp))
                }
            }
        }

        Spacer(Modifier.height(36.dp))

        Button(
            onClick = onNext,
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Violet)
        ) {
            Text("Next →", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(24.dp))
    }
}

// ─── Slide 2: Voice Preference ────────────────────────────────────────────────

@Composable
private fun DemoSlide2(
    voice: String,
    onVoiceChanged: (String) -> Unit,
    onNext: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("Choose Max's voice", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Text("How should Max sound when speaking to you?", color = Color.White.copy(alpha = 0.65f), fontSize = 15.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(40.dp))

        listOf(
            Triple("female", "Female", Icons.Default.RecordVoiceOver),
            Triple("male", "Male", Icons.Default.VoiceChat)
        ).forEach { (value, label, icon) ->
            val selected = voice == value
            val borderColor by animateColorAsState(if (selected) Violet else Color.White.copy(alpha = 0.20f), label = "border")
            val bgColor by animateColorAsState(if (selected) Violet.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.05f), label = "bg")

            Surface(
                onClick = { onVoiceChanged(value) },
                modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                shape = RoundedCornerShape(16.dp),
                color = bgColor,
                border = BorderStroke(1.5.dp, borderColor)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 18.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier.size(44.dp).clip(CircleShape).background(
                            if (selected) Violet else Color.White.copy(alpha = 0.12f)
                        ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(22.dp))
                    }
                    Spacer(Modifier.width(16.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                        Text(
                            if (value == "female") "Warm and expressive" else "Deep and confident",
                            color = Color.White.copy(alpha = 0.55f), fontSize = 13.sp
                        )
                    }
                    if (selected) {
                        Icon(Icons.Default.Check, contentDescription = null, tint = VioletLight, modifier = Modifier.size(20.dp))
                    }
                }
            }
        }

        Spacer(Modifier.height(40.dp))

        Button(
            onClick = onNext,
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Violet)
        ) {
            Text("Next →", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

// ─── Slide 3: Summary + Launch ────────────────────────────────────────────────

@Composable
private fun DemoSlide3(
    name: String,
    gender: String,
    voice: String,
    isLoading: Boolean,
    onLaunch: () -> Unit
) {
    val displayName = name.ifBlank { "there" }
    val genderLabel = when (gender) {
        "male" -> "Male"
        "female" -> "Female"
        else -> "Not specified"
    }
    val voiceLabel = if (voice == "female") "Female — warm & expressive" else "Male — deep & confident"

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Orb placeholder circle
        Box(
            modifier = Modifier.size(100.dp).clip(CircleShape).background(
                Brush.radialGradient(colors = listOf(Violet, Color(0xFF4F46E5)))
            ),
            contentAlignment = Alignment.Center
        ) {
            Text("M", color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.Bold)
        }

        Spacer(Modifier.height(28.dp))

        Text("Hey $displayName, I'm Max!", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Text("Ready to be your AI personal assistant.", color = Color.White.copy(alpha = 0.65f), fontSize = 15.sp, textAlign = TextAlign.Center)

        Spacer(Modifier.height(36.dp))

        // Summary card
        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            color = Color.White.copy(alpha = 0.08f),
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.18f))
        ) {
            Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SummaryRow(label = "Name", value = name.ifBlank { "Not set" })
                HorizontalDivider(color = Color.White.copy(alpha = 0.12f))
                SummaryRow(label = "Gender", value = genderLabel)
                HorizontalDivider(color = Color.White.copy(alpha = 0.12f))
                SummaryRow(label = "Voice", value = voiceLabel)
            }
        }

        Spacer(Modifier.height(40.dp))

        Button(
            onClick = onLaunch,
            enabled = !isLoading,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Violet)
        ) {
            if (isLoading) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(22.dp), strokeWidth = 2.dp)
            } else {
                Text("Start talking to Max ✨", fontSize = 17.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun SummaryRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = Color.White.copy(alpha = 0.55f), fontSize = 14.sp)
        Text(value, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
    }
}

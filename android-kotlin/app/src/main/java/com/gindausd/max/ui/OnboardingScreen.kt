package com.gindausd.max.ui

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gindausd.max.OrbState
import com.gindausd.max.ui.components.OrbView
import com.gindausd.max.ui.theme.BackgroundDark
import com.gindausd.max.ui.theme.OrangePrimary
import kotlinx.coroutines.launch

private data class OnboardingPage(
    val title: String,
    val subtitle: String
)

private val onboardingPages = listOf(
    OnboardingPage("Meet Max", "Your intelligent AI assistant, powered by Claude. Ready to help with anything."),
    OnboardingPage("Press the Orb", "Simply tap the glowing orb to start a conversation. It's that easy."),
    OnboardingPage("Stay Notified", "Get your daily briefing and reminders delivered right to your notification island."),
    OnboardingPage("One-Press Shortcut", "Set Max as your quick-launch shortcut using the volume or side button."),
    OnboardingPage("Home Screen Widget", "Add the Max widget to your home screen for instant access without unlocking."),
    OnboardingPage("You're All Set!", "Max is ready to assist you. Start talking and discover what's possible.")
)

@Composable
fun OnboardingScreen(onComplete: () -> Unit) {
    val pagerState = rememberPagerState(pageCount = { onboardingPages.size })
    val scope = rememberCoroutineScope()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(BackgroundDark)
    ) {
        // Skip button
        TextButton(
            onClick = onComplete,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(16.dp)
        ) {
            Text("Skip", color = Color(0xFF8A7A6A), fontSize = 15.sp)
        }

        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            OnboardingPageContent(page = page, pageData = onboardingPages[page])
        }

        // Bottom controls
        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 48.dp, start = 32.dp, end = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Page indicator dots
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                repeat(onboardingPages.size) { index ->
                    val isSelected = index == pagerState.currentPage
                    Box(
                        modifier = Modifier
                            .size(if (isSelected) 24.dp else 8.dp, 8.dp)
                            .clip(CircleShape)
                            .background(if (isSelected) OrangePrimary else Color(0xFF3D2E18))
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            val isLastPage = pagerState.currentPage == onboardingPages.size - 1
            Button(
                onClick = {
                    if (isLastPage) {
                        onComplete()
                    } else {
                        scope.launch {
                            pagerState.animateScrollToPage(pagerState.currentPage + 1)
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = OrangePrimary)
            ) {
                Text(
                    text = if (isLastPage) "Start Talking to Max" else "Next",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

@Composable
private fun OnboardingPageContent(page: Int, pageData: OnboardingPage) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Visual element per page
        when (page) {
            0 -> OrbView(state = OrbState.IDLE, sizeDp = 120.dp)
            1 -> PulsingOrbWithRings()
            2 -> NotificationMockup()
            3 -> PhoneMockup()
            4 -> WidgetMockup()
            5 -> GlowingOrb()
        }

        Spacer(modifier = Modifier.height(40.dp))

        Text(
            text = pageData.title,
            color = Color.White,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = pageData.subtitle,
            color = Color(0xFF8A7A6A),
            fontSize = 16.sp,
            textAlign = TextAlign.Center,
            lineHeight = 24.sp
        )

        Spacer(modifier = Modifier.height(100.dp))
    }
}

@Composable
private fun PulsingOrbWithRings() {
    val infiniteTransition = rememberInfiniteTransition(label = "rings")
    val ringScale1 by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.5f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "ring1"
    )
    val ringAlpha1 by infiniteTransition.animateFloat(
        initialValue = 0.6f,
        targetValue = 0f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "ring1alpha"
    )

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.size(140.dp)
    ) {
        Box(
            modifier = Modifier
                .size(100.dp)
                .scale(ringScale1)
                .clip(CircleShape)
                .background(OrangePrimary.copy(alpha = ringAlpha1))
        )
        OrbView(state = OrbState.LISTENING, sizeDp = 100.dp)
    }
}

@Composable
private fun NotificationMockup() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(80.dp)
            .background(Color(0xFF1A1008), RoundedCornerShape(20.dp))
            .padding(16.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .background(OrangePrimary, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Notifications,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Text("Max", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Text("Your morning briefing is ready!", color = Color(0xFF8A7A6A), fontSize = 12.sp)
            }
        }
    }
}

@Composable
private fun PhoneMockup() {
    Box(
        modifier = Modifier
            .width(100.dp)
            .height(170.dp)
            .background(Color(0xFF1A1008), RoundedCornerShape(24.dp))
            .padding(8.dp),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Default.PhoneAndroid,
            contentDescription = null,
            tint = OrangePrimary,
            modifier = Modifier.size(64.dp)
        )
        Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .width(4.dp)
                .height(40.dp)
                .background(OrangePrimary, RoundedCornerShape(2.dp))
        )
    }
}

@Composable
private fun WidgetMockup() {
    Box(
        modifier = Modifier
            .size(160.dp)
            .background(Color(0xFF1A1008), RoundedCornerShape(24.dp))
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                imageVector = Icons.Default.Widgets,
                contentDescription = null,
                tint = OrangePrimary,
                modifier = Modifier.size(32.dp)
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text("Max", color = OrangePrimary, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Text("Tap to talk", color = Color(0xFF8A7A6A), fontSize = 12.sp)
        }
    }
}

@Composable
private fun GlowingOrb() {
    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(150.dp)) {
        Box(
            modifier = Modifier
                .size(150.dp)
                .background(
                    OrangePrimary.copy(alpha = 0.15f),
                    CircleShape
                )
        )
        Box(
            modifier = Modifier
                .size(110.dp)
                .background(
                    OrangePrimary.copy(alpha = 0.1f),
                    CircleShape
                )
        )
        OrbView(state = OrbState.IDLE, sizeDp = 130.dp)
    }
}

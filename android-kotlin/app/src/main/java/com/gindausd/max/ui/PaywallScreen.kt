package com.gindausd.max.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gindausd.max.OrbState
import com.gindausd.max.ui.components.OrbView
import com.gindausd.max.ui.theme.BackgroundDark
import com.gindausd.max.ui.theme.OrangePrimary

private data class PlanOption(
    val id: String,
    val name: String,
    val price: String,
    val period: String,
    val isBestValue: Boolean = false,
    val monthlyEquivalent: String? = null
)

private val plans = listOf(
    PlanOption(
        id = "monthly",
        name = "Monthly",
        price = "$9.99",
        period = "per month"
    ),
    PlanOption(
        id = "yearly",
        name = "Yearly",
        price = "$119.99",
        period = "per year",
        isBestValue = true,
        monthlyEquivalent = "$10.00/mo"
    )
)

private val features = listOf(
    "Unlimited voice conversations",
    "Claude Sonnet AI — state of the art",
    "Note-taking & memory",
    "Calendar & reminder management",
    "Morning briefings",
    "Email & call assistance",
    "Travel & directions support",
    "Priority updates"
)

@Composable
fun PaywallScreen(
    onNavigateBack: () -> Unit,
    onSubscribed: () -> Unit
) {
    var selectedPlan by remember { mutableStateOf("yearly") }
    var isLoading by remember { mutableStateOf(false) }
    val scrollState = rememberScrollState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(BackgroundDark)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Close button
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(Icons.Default.Close, contentDescription = "Close", tint = Color(0xFF8A7A6A))
                }
            }

            // Header
            OrbView(state = OrbState.IDLE, sizeDp = 80.dp)
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Unlock Max",
                color = Color.White,
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Get the full AI assistant experience",
                color = Color(0xFF8A7A6A),
                fontSize = 15.sp,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(28.dp))

            // Feature list
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF1A1008), RoundedCornerShape(16.dp))
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                features.forEach { feature ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(22.dp)
                                .background(OrangePrimary.copy(alpha = 0.15f), RoundedCornerShape(50))
                                .padding(3.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = null,
                                tint = OrangePrimary,
                                modifier = Modifier.size(14.dp)
                            )
                        }
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(text = feature, color = Color.White, fontSize = 14.sp)
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Plan selection
            Text(
                text = "Choose your plan",
                color = Color(0xFF8A7A6A),
                fontSize = 13.sp,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(10.dp))

            plans.forEach { plan ->
                PlanCard(
                    plan = plan,
                    isSelected = selectedPlan == plan.id,
                    onClick = { selectedPlan = plan.id }
                )
                Spacer(modifier = Modifier.height(10.dp))
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Trial note
            Text(
                text = "Start your 7-day free trial. Cancel anytime.",
                color = OrangePrimary,
                fontSize = 13.sp,
                textAlign = TextAlign.Center,
                fontWeight = FontWeight.SemiBold
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Subscribe button
            // TODO: Integrate Google Play Billing
            // 1. val billingClient = BillingClient.newBuilder(context).build()
            // 2. Launch billingClient.startConnection(...)
            // 3. On connected: queryProductDetailsAsync for your subscription SKUs
            // 4. Launch billingFlowParams with the selected plan's ProductDetails
            // 5. Handle PurchasesUpdatedListener result -> acknowledge purchase -> call onSubscribed()
            Button(
                onClick = {
                    isLoading = true
                    // TODO: Replace with actual Google Play Billing flow
                    isLoading = false
                    onSubscribed()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = OrangePrimary)
            ) {
                if (isLoading) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp))
                } else {
                    val plan = plans.firstOrNull { it.id == selectedPlan }
                    Text(
                        text = "Subscribe — ${plan?.price ?: ""} ${plan?.period ?: ""}",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            TextButton(
                onClick = {
                    // TODO: Implement Google Play restore purchases flow
                    // billingClient.queryPurchasesAsync(BillingClient.ProductType.SUBS) { ... }
                }
            ) {
                Text("Restore Purchases", color = Color(0xFF8A7A6A), fontSize = 13.sp)
            }

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "Subscription auto-renews. Manage in Play Store settings.",
                color = Color(0xFF5C4A30),
                fontSize = 11.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
private fun PlanCard(
    plan: PlanOption,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(
                if (isSelected) OrangePrimary.copy(alpha = 0.12f) else Color(0xFF1A1008)
            )
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = if (isSelected) OrangePrimary else Color(0xFF3D2E18),
                shape = RoundedCornerShape(16.dp)
            )
            .clickable(onClick = onClick)
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = plan.name,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    if (plan.isBestValue) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Box(
                            modifier = Modifier
                                .background(OrangePrimary, RoundedCornerShape(6.dp))
                                .padding(horizontal = 8.dp, vertical = 2.dp)
                        ) {
                            Text(
                                text = "Best Value",
                                color = Color.White,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
                if (plan.monthlyEquivalent != null) {
                    Text(
                        text = "Billed annually (${plan.monthlyEquivalent})",
                        color = Color(0xFF8A7A6A),
                        fontSize = 12.sp
                    )
                }
            }

            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = plan.price,
                    color = if (isSelected) OrangePrimary else Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = plan.period,
                    color = Color(0xFF8A7A6A),
                    fontSize = 11.sp
                )
            }
        }
    }
}

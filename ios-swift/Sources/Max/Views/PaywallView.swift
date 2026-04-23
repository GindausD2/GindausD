import StoreKit
import SwiftUI

// MARK: - PaywallView
//
// Shown after sign-in for non-demo users who don't yet have a subscription.
// Blocked access: user cannot reach HomeView until they subscribe.

struct PaywallView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var store = StoreKitService.shared
    @State private var selectedPlan: String = StoreKitService.yearlyID

    private let violet     = Color(hex: "#7C3AED")
    private let violetDeep = Color(hex: "#3B1A8A")
    private let amber      = Color(hex: "#F59E0B")

    private let highlights: [(icon: String, text: String)] = [
        ("infinity",        "Unlimited conversations with Max"),
        ("bolt.fill",       "Priority responses, no wait"),
        ("brain.head.profile", "Remembers your preferences & notes"),
        ("bell.badge.fill", "Smart reminders and email alerts")
    ]

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Hero ───────────────────────────────────────────────
                    VStack(spacing: 18) {
                        MaxLogoView(width: 90)
                            .padding(.top, 60)

                        VStack(spacing: 8) {
                            Text("Unlock Max Pro")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Your personal AI assistant,\nalways by your side.")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 36)

                    // ── Highlights ─────────────────────────────────────────
                    VStack(spacing: 0) {
                        ForEach(highlights, id: \.text) { item in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(.white.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: item.icon)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                                Text(item.text)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.90))
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.50))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 13)
                            if item.text != highlights.last?.text {
                                Divider()
                                    .background(.white.opacity(0.12))
                                    .padding(.leading, 70)
                            }
                        }
                    }
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    // ── Plan Cards ─────────────────────────────────────────
                    VStack(spacing: 10) {
                        PaywallPlanCard(
                            title: "Yearly",
                            price: store.yearlyProduct?.displayPrice ?? "$119.99",
                            period: "/ year",
                            subtext: "Just \(monthlyEquivalent)/mo — save 17%",
                            badge: "Best Value",
                            isSelected: selectedPlan == StoreKitService.yearlyID
                        ) { selectedPlan = StoreKitService.yearlyID }

                        PaywallPlanCard(
                            title: "Monthly",
                            price: store.monthlyProduct?.displayPrice ?? "$9.99",
                            period: "/ month",
                            subtext: "Flexible — cancel anytime",
                            badge: nil,
                            isSelected: selectedPlan == StoreKitService.monthlyID
                        ) { selectedPlan = StoreKitService.monthlyID }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // ── Error ──────────────────────────────────────────────
                    if let err = store.purchaseError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 10)
                    }

                    // ── Subscribe Button ───────────────────────────────────
                    Button {
                        Task {
                            let product = selectedPlan == StoreKitService.yearlyID
                                ? store.yearlyProduct : store.monthlyProduct
                            if let product { await store.purchase(product) }
                        }
                    } label: {
                        ZStack {
                            if store.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(ctaLabel)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#9F5FF8"), Color(hex: "#6D28D9")],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .shadow(color: violet.opacity(0.45), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isLoading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // ── Footer Links ───────────────────────────────────────
                    VStack(spacing: 10) {
                        Button {
                            Task { await store.restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .disabled(store.isLoading)

                        HStack(spacing: 4) {
                            Text("By subscribing you agree to our")
                            Link("Terms", destination: URL(string: "https://www.anthropic.com/legal/consumer-terms")!)
                            Text("and")
                            Link("Privacy Policy", destination: URL(string: "https://www.anthropic.com/legal/privacy")!)
                        }
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.40))

                        Text("Subscription auto-renews. Cancel anytime in\nSettings → Apple ID → Subscriptions.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.35))
                            .multilineTextAlignment(.center)

                        // Sign out link at bottom so user can switch accounts
                        Button {
                            authService.signOut()
                        } label: {
                            Text("Sign out")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .padding(.top, 4)
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        // Navigate to HomeView once subscribed
        .onChange(of: store.isSubscribed) { _, subscribed in
            // RootView observes this too — no explicit push needed
            _ = subscribed
        }
        .task { await store.loadProducts() }
    }

    // MARK: - Helpers

    private var background: some View {
        LinearGradient(
            colors: [Color(hex: "#1E0845"), Color(hex: "#3B1A8A"), Color(hex: "#6D28D9")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var monthlyEquivalent: String {
        guard let yearly = store.yearlyProduct else { return "$8.33" }
        let monthly = yearly.price / 12
        let fmt = yearly.priceFormatStyle
        return (try? monthly.formatted(fmt)) ?? "$8.33"
    }

    private var ctaLabel: String {
        let price = selectedPlan == StoreKitService.yearlyID
            ? (store.yearlyProduct?.displayPrice ?? "$119.99")
            : (store.monthlyProduct?.displayPrice ?? "$9.99")
        let period = selectedPlan == StoreKitService.yearlyID ? "year" : "month"
        return "Subscribe — \(price)/\(period)"
    }
}

// MARK: - Plan Card

private struct PaywallPlanCard: View {
    let title: String
    let price: String
    let period: String
    let subtext: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? .white : .white.opacity(0.30), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(.white).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: "#1E0845"))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.white, in: Capsule())
                        }
                    }
                    Text(subtext)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? .white.opacity(0.18) : .white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isSelected ? .white.opacity(0.60) : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Logo (duplicated from HomeView for use here without circular deps)

private struct MaxLogoView: View {
    var color: Color = .white
    var width: CGFloat

    private var height: CGFloat { width * 50 / 100 }

    var body: some View {
        Canvas(opaque: false, colorMode: .linear) { context, size in
            let u = size.width / 100.0
            func ellipse(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (cx - r) * u, y: (cy - r) * u,
                                       width: 2 * r * u, height: 2 * r * u))
            }
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 18, cy: 25, r: 24), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 29, cy: 25, r: 19), with: .color(.black))
            }
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 50, cy: 25, r: 17), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 50, cy: 25, r: 10), with: .color(.black))
            }
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 82, cy: 25, r: 24), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 71, cy: 25, r: 19), with: .color(.black))
            }
        }
        .frame(width: width, height: height)
    }
}

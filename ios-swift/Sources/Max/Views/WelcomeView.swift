import SwiftUI
import AuthenticationServices

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var currentPage: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(initialMode: AuthEntryMode? = nil) {
        _currentPage = State(initialValue: initialMode?.page ?? 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CompanionCanvas()
                ambientBlobs

                VStack(spacing: 0) {
                    navigationControl
                        .padding(.top, geo.safeAreaInsets.top + 18)
                        .padding(.bottom, 10)

                    if currentPage == 1 {
                        WelcomePage(onLogin: { currentPage = 0 }, onSignUp: { currentPage = 2 })
                    } else if currentPage == 3 {
                        PlanPage(onBack: {
                            authService.signOut()
                            currentPage = 2
                        })
                    } else {
                        TabView(selection: $currentPage) {
                            LoginPage().tag(0)
                            SignUpPage(onSignedUp: { currentPage = 3 }).tag(2)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: currentPage)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Returning signed-in user who hasn't subscribed yet → jump to plan page
            if authService.currentUser != nil && authService.currentUser?.isDemo != true {
                currentPage = 3
            }
        }
        .onChange(of: authService.currentUser) { _, user in
            if user != nil && user?.isDemo != true { currentPage = 3 }
        }
    }

    // MARK: - Background

    private var ambientBlobs: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#315E73").opacity(0.07))
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: -90, y: -210)
            Circle()
                .fill(Color(hex: "#315E73").opacity(0.05))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 110, y: 280)
            Circle()
                .fill(Color(hex: "#315E73").opacity(0.04))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: 60, y: -60)
        }
    }

    // MARK: - Authentication slider

    @ViewBuilder private var navigationControl: some View {
        if currentPage == 0 || currentPage == 2 {
            HStack(spacing: 12) {
                Button { currentPage = 1 } label: {
                    Image(systemName: "arrow.left")
                        .font(.body.weight(.medium))
                        .frame(width: 44, height: 44)
                        .glassCard(cornerRadius: 22, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to welcome")
                AuthModeSlider(selection: Binding(
                    get: { currentPage == 0 ? .login : .signUp },
                    set: { currentPage = $0.page; authService.authError = nil }
                ))
            }
            .disabled(authService.isLoading)
            .padding(.horizontal, 24)
            .frame(maxWidth: 460)
        } else {
            CompanionWordmark()
                .padding(.vertical, 8)
        }
    }

}

// MARK: - Shared Apple Sign-In Handler

private func appleSignInHandler(authService: AuthService, linkGuest: Bool = true) -> (Result<ASAuthorization, Error>) -> Void {
    return { result in
        if case .failure(let error) = result {
            Task { @MainActor in authService.cancelAppleSignIn(); authService.authError = error.localizedDescription }
            return
        }
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else {
            Task { @MainActor in authService.authError = "Apple sign-in couldn't complete. Please try again." }
            return
        }
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        Task {
            await authService.signInWithApple(
                idToken: idToken,
                name: fullName.isEmpty ? nil : fullName,
                linkGuest: linkGuest
            )
        }
    }
}

// MARK: - Continue after the guest demo

struct DemoUpgradeView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        ZStack {
            CompanionCanvas()
            VStack(spacing: 22) {
                OrbView(state: .idle, size: 110)
                Text(authService.isDemoExpired ? "Your seven-day demo has ended" : "Keep Max with you")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Continue with Apple to choose your subscription and keep your saved thoughts.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                SignInWithAppleButton(.continue, onRequest: { request in
                    authService.prepareAppleSignIn(request)
                }, onCompletion: appleSignInHandler(authService: authService))
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .disabled(authService.isLoading)
                if authService.isLoading { ProgressView() }
                if let error = authService.authError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                if !authService.isDemoExpired {
                    Button("Back to my demo") { authService.cancelDemoUpgrade() }
                }
            }
            .padding(30)
            .frame(maxWidth: 440)
        }
    }
}

// MARK: - Glass Action Button

private struct LiquidGlassPrimaryButton: View {
    var title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#315E73"), Color(hex: "#315E73")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.5)
                        )
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.45), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
        )
        .foregroundStyle(.white)
        .shadow(color: Color(hex: "#315E73").opacity(0.35), radius: 14, x: 0, y: 5)
        .shadow(color: Color(hex: "#315E73").opacity(0.12), radius: 30, x: 0, y: 10)
        .disabled(isLoading || isDisabled)
        .opacity(isDisabled ? 0.55 : 1.0)
    }
}

// MARK: - Entry screens

private struct LoginPage: View {
    @State private var showDemo = false

    var body: some View {
        AuthEntryPage(mode: .login, onDemo: { showDemo = true })
            .fullScreenCover(isPresented: $showDemo) { DemoOnboardingView() }
    }
}

private struct SignUpPage: View {
    var onSignedUp: () -> Void
    @EnvironmentObject private var authService: AuthService
    @State private var showDemo = false

    var body: some View {
        AuthEntryPage(mode: .signUp, onDemo: { showDemo = true })
            .fullScreenCover(isPresented: $showDemo) { DemoOnboardingView() }
            .onChange(of: authService.currentUser) { _, user in
                if user != nil && user?.isDemo != true { onSignedUp() }
            }
    }
}

private struct AuthEntryPage: View {
    let mode: AuthEntryMode
    var onDemo: () -> Void
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme
    private var isLogin: Bool { mode == .login }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                EntryHero(
                    eyebrow: isLogin ? "YOUR SPACE IS HERE" : "MEET YOUR EVERYDAY COMPANION",
                    title: isLogin ? "A little more\nyou, again." : "Make room\nfor what matters.",
                    subtitle: isLogin ? "Pick up your thoughts, plans and little moments with Max." : "A thought, a plan, a little help.\nLet’s make your day feel lighter.",
                    orbSize: 96
                )

                VStack(alignment: .leading, spacing: 16) {
                    Text(isLogin ? "Welcome back" : "Your space starts here")
                        .font(.title3.weight(.semibold))
                    if isLogin && authService.hasGuestSession {
                        Text("Signing in to another account keeps your demo’s saved items separate.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    SignInWithAppleButton(
                        isLogin ? .signIn : .signUp,
                        onRequest: { authService.prepareAppleSignIn($0) },
                        onCompletion: appleSignInHandler(authService: authService, linkGuest: !isLogin)
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .disabled(authService.isLoading)
                    if authService.isLoading { ProgressView().frame(maxWidth: .infinity) }
                    if let error = authService.authError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    Label("Your own place for thoughts and plans", systemImage: "lock")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 28)

                Button(action: onDemo) {
                    HStack(spacing: 8) {
                        Text("Just looking around?").foregroundStyle(.secondary)
                        Text("Try demo").fontWeight(.semibold)
                        Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                    }
                    .font(.subheadline)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(authService.isLoading)
                Text("7 days to meet Max. No Apple sign-in or payment needed for the demo.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 34)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct WelcomePage: View {
    var onLogin: () -> Void
    var onSignUp: () -> Void
    @EnvironmentObject private var authService: AuthService
    @State private var showDemo = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                EntryHero(eyebrow: "A LITTLE SPACE FOR YOUR DAY", title: "Life feels lighter.\nWith Max.", subtitle: "Your thoughts. Your plans.\nA companion for the everyday.", orbSize: 164)
                VStack(spacing: 14) {
                    EntryPrimaryButton(title: "Get started", action: onSignUp)
                    Button { showDemo = true } label: {
                        HStack {
                            Text("Try the 7-day demo").fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .padding(18)
                        .glassCard(cornerRadius: 22, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(authService.isLoading)
                    Text("No Apple sign-in or payment for the demo")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button(action: onLogin) {
                    Text("Already have a space here? ").foregroundStyle(.secondary)
                    + Text("Log in").bold()
                }
                .font(.subheadline)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
            }
            .padding(28)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .fullScreenCover(isPresented: $showDemo) { DemoOnboardingView() }
    }
}

// MARK: - Plan Page (Step 3 of signup)

struct PlanPage: View {
    var onBack: () -> Void
    @EnvironmentObject private var authService: AuthService
    @StateObject private var store = StoreKitService.shared
    @State private var selectedPlan: String = StoreKitService.monthlyID

    private let violet = Color(hex: "#315E73")
    private let amber  = Color(hex: "#F59E0B")

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(amber.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(amber)
                    }
                    Text("Choose Your Plan")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Start your Max Pro subscription")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 28)

                // Plan cards
                VStack(spacing: 10) {
                    WelcomePlanCard(
                        title: "Monthly",
                        price: store.monthlyProduct?.displayPrice ?? "Unavailable",
                        period: "/ month",
                        subtext: "Flexible · cancel anytime",
                        badge: nil,
                        isSelected: selectedPlan == StoreKitService.monthlyID,
                        violet: violet
                    ) { selectedPlan = StoreKitService.monthlyID }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)

                // What's included
                GlassCard(
                    cornerRadius: 20,
                    depth: .ultraThin,
                    padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
                ) {
                    VStack(spacing: 10) {
                        ForEach([
                            ("bubble.left.and.bubble.right", "AI conversations with daily limits"),
                            ("waveform",           "Voice and text conversations"),
                            ("lock.fill",          "Memories saved on this iPhone"),
                            ("bell.badge.fill",    "Smart reminders & alerts")
                        ], id: \.0) { icon, text in
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(violet)
                                    .frame(width: 20)
                                Text(text)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(violet)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)

                // Error
                if let err = store.purchaseError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 10)
                }

                // Subscribe button
                LiquidGlassPrimaryButton(
                    title: store.isLoading ? "" : subscribeLabel,
                    isLoading: store.isLoading,
                    isDisabled: store.isLoading || selectedProductUnavailable
                ) {
                    Task {
                        let product = selectedPlan == StoreKitService.yearlyID
                            ? store.yearlyProduct : store.monthlyProduct
                        if let product { await store.purchase(product) }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)

                if selectedProductUnavailable && !store.isLoading {
                    Text("Subscriptions are temporarily unavailable. Please try again later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 12)
                }

                // Footer
                VStack(spacing: 8) {
                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundStyle(violet)
                    }
                    .disabled(store.isLoading)

                    Text("Includes up to 100 AI requests and 3,000 OpenAI voice characters per UTC day. Each tool continuation counts as a request. Max’s voice is AI-generated.")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("Auto-renews. Cancel anytime in Settings → Apple ID.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 16)

                Button { onBack() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left").font(.caption)
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize)
        .task { await store.loadProducts() }
    }

    private var subscribeLabel: String {
        let product = selectedPlan == StoreKitService.yearlyID ? store.yearlyProduct : store.monthlyProduct
        guard let product else { return "Subscriptions unavailable" }
        let period = selectedPlan == StoreKitService.yearlyID ? "year" : "month"
        return "Subscribe — \(product.displayPrice)/\(period)"
    }

    private var selectedProductUnavailable: Bool {
        selectedPlan == StoreKitService.yearlyID ? store.yearlyProduct == nil : store.monthlyProduct == nil
    }
}

private struct WelcomePlanCard: View {
    let title: String
    let price: String
    let period: String
    let subtext: String
    let badge: String?
    let isSelected: Bool
    let violet: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? violet : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(violet).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(violet, in: Capsule())
                        }
                    }
                    Text(subtext)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isSelected ? violet : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    WelcomeView().environmentObject(AuthService.shared)
}

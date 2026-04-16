import SwiftUI
import AuthenticationServices

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var currentPage: Int = 1   // Start on Welcome page

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundGradient.ignoresSafeArea()
                ambientBlobs

                VStack(spacing: 0) {
                    pageIndicator
                        .padding(.top, geo.safeAreaInsets.top + 18)
                        .padding(.bottom, 10)

                    TabView(selection: $currentPage) {
                        LoginPage(onNavigateToWelcome: { currentPage = 1 })
                            .tag(0)
                        WelcomePage(onLogin: { currentPage = 0 }, onSignUp: { currentPage = 2 })
                            .tag(1)
                        SignUpPage(onBack: { currentPage = 1 })
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentPage)
                }
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#07041A"), location: 0.0),
                .init(color: Color(hex: "#160A38"), location: 0.3),
                .init(color: Color(hex: "#2D1B69"), location: 0.6),
                .init(color: Color(hex: "#4F46E5"), location: 0.85),
                .init(color: Color(hex: "#7C3AED"), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var ambientBlobs: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#7C3AED").opacity(0.22))
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: -90, y: -210)
            Circle()
                .fill(Color(hex: "#4F46E5").opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 110, y: 280)
            Circle()
                .fill(Color(hex: "#C084FC").opacity(0.10))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: 60, y: -60)
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(currentPage == i ? Color.white : Color.white.opacity(0.30))
                    .frame(width: currentPage == i ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule().strokeBorder(.white.opacity(0.20), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Glass Input Field helper

private struct LiquidGlassField<F: Hashable>: View {
    var label: String
    @Binding var text: String
    var placeholder: String
    var isSecure: Bool = false
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var focused: FocusState<F?>.Binding
    var fieldID: F

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.70))
                .padding(.leading, 2)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .if(contentType != nil) { v in
                            v.textContentType(contentType!)
                        }
                }
            }
            .focused(focused, equals: fieldID)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .foregroundStyle(.white)
            .tint(Color(hex: "#A78BFA"))
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                    // Specular top
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.16), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.5)
                            )
                        )
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.40), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                }
            )
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
                            colors: [
                                Color(hex: "#7C3AED"),
                                Color(hex: "#4F46E5")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                // Specular
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
        .shadow(color: Color(hex: "#7C3AED").opacity(0.5), radius: 14, x: 0, y: 5)
        .shadow(color: Color(hex: "#7C3AED").opacity(0.2), radius: 30, x: 0, y: 10)
        .disabled(isLoading || isDisabled)
        .opacity(isDisabled ? 0.55 : 1.0)
    }
}

// MARK: - Glass Secondary Button (outline)

private struct LiquidGlassOutlineButton: View {
    var title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                }
                Text(title).font(.body.weight(.semibold))
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.14), .clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.5)
                        )
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.40), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            }
        )
        .foregroundStyle(.white)
    }
}

// MARK: - Login Page

private struct LoginPage: View {
    var onNavigateToWelcome: () -> Void
    @EnvironmentObject private var authService: AuthService
    @State private var email: String = ""
    @State private var password: String = ""
    @FocusState private var focusedField: Field?
    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 48)

                // Header
                VStack(spacing: 8) {
                    Text("Welcome back")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Sign in to continue with Max")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.bottom, 32)

                // Glass card
                GlassCard(
                    cornerRadius: 26,
                    depth: .thin,
                    padding: EdgeInsets(top: 26, leading: 22, bottom: 26, trailing: 22)
                ) {
                    VStack(spacing: 18) {
                        LiquidGlassField(
                            label: "Email",
                            text: $email,
                            placeholder: "you@example.com",
                            contentType: .emailAddress,
                            keyboard: .emailAddress,
                            focused: $focusedField,
                            fieldID: Field.email
                        )
                        LiquidGlassField(
                            label: "Password",
                            text: $password,
                            placeholder: "••••••••",
                            isSecure: true,
                            focused: $focusedField,
                            fieldID: Field.password
                        )
                        LiquidGlassPrimaryButton(
                            title: "Login",
                            isLoading: authService.isLoading,
                            isDisabled: email.isEmpty || password.isEmpty
                        ) {
                            focusedField = nil
                            Task { await authService.signIn(email: email, password: password) }
                        }
                    }
                }
                .padding(.horizontal, 22)

                // Sign-up link
                Button { onNavigateToWelcome() } label: {
                    HStack(spacing: 5) {
                        Text("Don't have an account?")
                            .foregroundStyle(.white.opacity(0.60))
                        Text("Sign up →")
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .padding(.top, 22)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Welcome Page (Center)

private struct WelcomePage: View {
    var onLogin: () -> Void
    var onSignUp: () -> Void
    @EnvironmentObject private var authService: AuthService

    @State private var showDemoOnboarding: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            OrbView(state: .idle, size: 120)
                .padding(.bottom, 28)

            GlassCard(
                cornerRadius: 26,
                depth: .thin,
                padding: EdgeInsets(top: 22, leading: 28, bottom: 22, trailing: 28)
            ) {
                VStack(spacing: 12) {
                    MaxLogoView(color: .white, width: 180)
                        .padding(.bottom, 2)
                    Text("Your AI personal assistant")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.80))
                        .multilineTextAlignment(.center)
                    Text("Powered by Claude")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 44)
            .padding(.bottom, 32)

            HStack(spacing: 14) {
                Button { onLogin() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left").font(.caption.weight(.semibold))
                        Text("Login").font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(GlassPillButtonStyle())

                Button { onSignUp() } label: {
                    HStack(spacing: 6) {
                        Text("Get started").font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.right").font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(GlassPillButtonStyle(filled: true))
            }
            .padding(.bottom, 18)

            // Try Demo — opens the sliding onboarding flow
            Button {
                showDemoOnboarding = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                    Text("Try Demo")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.60))
            }
            .disabled(authService.isLoading)
            .fullScreenCover(isPresented: $showDemoOnboarding) {
                DemoOnboardingView()
                    .environmentObject(authService)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Sign Up Page

private struct SignUpPage: View {
    var onBack: () -> Void
    @EnvironmentObject private var authService: AuthService
    @State private var showEmailForm: Bool = false
    @State private var name: String = ""
    @State private var email: String = ""
    @FocusState private var focusedField: Field?
    enum Field { case name, email }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 48)

                VStack(spacing: 8) {
                    Text("Create account")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Choose how you'd like to sign up")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.bottom, 32)

                GlassCard(
                    cornerRadius: 26,
                    depth: .thin,
                    padding: EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22)
                ) {
                    VStack(spacing: 12) {

                        // Google
                        LiquidGlassOutlineButton(title: "Continue with Google", icon: nil) {
                            Task { await authService.signInWithGoogle() }
                        }
                        .overlay(
                            HStack {
                                ZStack {
                                    Circle().fill(.white).frame(width: 22, height: 22)
                                    Text("G")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                                }
                                .padding(.leading, 16)
                                Spacer()
                            }
                            .allowsHitTesting(false)
                        )

                        // Apple
                        SignInWithAppleButton(
                            onRequest: { $0.requestedScopes = [.fullName, .email] },
                            onCompletion: handleAppleSignIn
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.20), .clear],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(height: 0.5)
                        }

                        // Email toggle
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showEmailForm.toggle()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill").font(.system(size: 15))
                                Text("Continue with Email").font(.body.weight(.semibold))
                                Spacer()
                                Image(systemName: showEmailForm ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.vertical, 15)
                            .padding(.horizontal, 16)
                        }
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.14), .clear],
                                            startPoint: .top,
                                            endPoint: UnitPoint(x: 0.5, y: 0.5)
                                        )
                                    )
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.40), .white.opacity(0.08)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.0
                                    )
                            }
                        )
                        .foregroundStyle(.white)

                        // Inline email form
                        if showEmailForm {
                            VStack(spacing: 14) {
                                LiquidGlassField(
                                    label: "Your name",
                                    text: $name,
                                    placeholder: "Jane Doe",
                                    contentType: .name,
                                    focused: $focusedField,
                                    fieldID: Field.name
                                )
                                LiquidGlassField(
                                    label: "Email",
                                    text: $email,
                                    placeholder: "you@example.com",
                                    contentType: .emailAddress,
                                    keyboard: .emailAddress,
                                    focused: $focusedField,
                                    fieldID: Field.email
                                )
                                LiquidGlassPrimaryButton(
                                    title: "Create Account",
                                    isLoading: authService.isLoading,
                                    isDisabled: name.isEmpty || email.isEmpty
                                ) {
                                    focusedField = nil
                                    Task { await authService.signUp(name: name, email: email) }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.horizontal, 22)

                Button { onBack() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left").font(.caption)
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.top, 22)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential
        else { return }
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        Task {
            await authService.signInWithApple(
                name: fullName.isEmpty ? nil : fullName,
                email: credential.email
            )
        }
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

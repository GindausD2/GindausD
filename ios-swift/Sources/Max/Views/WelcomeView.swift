import SwiftUI
import AuthenticationServices

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var currentPage: Int = 1   // Start on Welcome page
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gradient
                backgroundGradient
                    .ignoresSafeArea()

                // Ambient blobs
                ambientBlobs

                VStack(spacing: 0) {
                    // Page indicator dots
                    pageIndicator
                        .padding(.top, geo.safeAreaInsets.top + 16)
                        .padding(.bottom, 8)

                    // Pages
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
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#2D1B69"), location: 0.0),
                .init(color: Color(hex: "#4F46E5"), location: 0.35),
                .init(color: Color(hex: "#7C3AED"), location: 0.65),
                .init(color: Color(hex: "#C084FC"), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var ambientBlobs: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#7C3AED").opacity(0.25))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -180)

            Circle()
                .fill(Color(hex: "#C084FC").opacity(0.2))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 100, y: 250)
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(currentPage == i ? Color.white : Color.white.opacity(0.35))
                    .frame(width: currentPage == i ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
    }
}

// MARK: - Login Page

private struct LoginPage: View {
    var onNavigateToWelcome: () -> Void

    @EnvironmentObject private var authService: AuthService
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // Header
                VStack(spacing: 8) {
                    Text("Welcome back")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Sign in to continue with Max")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.bottom, 36)

                // Card
                GlassCard(cornerRadius: 24, padding: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)) {
                    VStack(spacing: 18) {
                        // Email field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            TextField("you@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .textContentType(.emailAddress)
                                .focused($focusedField, equals: .email)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(
                                                    focusedField == .email
                                                        ? Color.white.opacity(0.5)
                                                        : Color.white.opacity(0.2),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .foregroundStyle(.white)
                                .tint(.white)
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            SecureField("••••••••", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(
                                                    focusedField == .password
                                                        ? Color.white.opacity(0.5)
                                                        : Color.white.opacity(0.2),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .foregroundStyle(.white)
                                .tint(.white)
                        }

                        if showError {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(Color.red.opacity(0.9))
                                .padding(.horizontal, 4)
                        }

                        // Login Button
                        Button {
                            login()
                        } label: {
                            ZStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Login")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#7C3AED"),
                                            Color(hex: "#4F46E5")
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .foregroundStyle(.white)
                        .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)
                    }
                }
                .padding(.horizontal, 24)

                // Sign up link
                Button {
                    onNavigateToWelcome()
                } label: {
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundStyle(.white.opacity(0.75))
                        Text("Sign up →")
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .padding(.top, 24)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else { return }
        showError = false
        focusedField = nil
        Task {
            await authService.signIn(email: email, password: password)
        }
    }
}

// MARK: - Welcome Page (Center)

private struct WelcomePage: View {
    var onLogin: () -> Void
    var onSignUp: () -> Void

    @EnvironmentObject private var authService: AuthService

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated Orb
            OrbView(state: .idle, size: 120)
                .padding(.bottom, 32)

            // Title Card
            GlassCard(cornerRadius: 24, padding: EdgeInsets(top: 20, leading: 28, bottom: 20, trailing: 28)) {
                VStack(spacing: 10) {
                    MaxLogoView(color: .white, width: 180)
                        .padding(.bottom, 4)
                    Text("Your AI personal assistant")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Text("Powered by Claude")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 36)

            // Navigation Pills
            HStack(spacing: 16) {
                Button {
                    onLogin()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.caption.weight(.semibold))
                        Text("Login")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(GlassPillButtonStyle())

                Button {
                    onSignUp()
                } label: {
                    HStack(spacing: 6) {
                        Text("Get started")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(GlassPillButtonStyle(filled: true))
            }
            .padding(.bottom, 20)

            // Demo Button
            Button {
                Task { await authService.startDemo() }
            } label: {
                if authService.isLoading {
                    ProgressView()
                        .tint(.white.opacity(0.7))
                        .padding(.vertical, 4)
                } else {
                    Text("Try Demo")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .disabled(authService.isLoading)

            Spacer()
        }
        .padding(.horizontal, 24)
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
                Spacer().frame(height: 60)

                VStack(spacing: 8) {
                    Text("Create account")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Choose how you'd like to sign up")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.bottom, 36)

                GlassCard(cornerRadius: 24, padding: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)) {
                    VStack(spacing: 14) {

                        // Google Sign In
                        Button {
                            Task { await authService.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 12) {
                                // Google "G" logo approximation
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 22, height: 22)
                                    Text("G")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                                }
                                Text("Continue with Google")
                                    .font(.body.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(.white)

                        // Apple Sign In
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleAppleSignIn(result: result)
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .cornerRadius(14)

                        // Email Sign Up
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showEmailForm.toggle()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 15))
                                Text("Continue with Email")
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Image(systemName: showEmailForm ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(.white)

                        // Inline Email Form
                        if showEmailForm {
                            VStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Your name")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.8))
                                    TextField("Jane Doe", text: $name)
                                        .textContentType(.name)
                                        .focused($focusedField, equals: .name)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(0.12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                                                )
                                        )
                                        .foregroundStyle(.white)
                                        .tint(.white)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Email")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.8))
                                    TextField("you@example.com", text: $email)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .textContentType(.emailAddress)
                                        .focused($focusedField, equals: .email)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(0.12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                                                )
                                        )
                                        .foregroundStyle(.white)
                                        .tint(.white)
                                }

                                Button {
                                    signUp()
                                } label: {
                                    ZStack {
                                        if authService.isLoading {
                                            ProgressView().tint(.white)
                                        } else {
                                            Text("Create Account")
                                                .font(.body.weight(.semibold))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#7C3AED"), Color(hex: "#4F46E5")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .foregroundStyle(.white)
                                .disabled(authService.isLoading || name.isEmpty || email.isEmpty)
                                .opacity(name.isEmpty || email.isEmpty ? 0.6 : 1.0)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Back link
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.caption)
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 24)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func signUp() {
        guard !name.isEmpty, !email.isEmpty else { return }
        focusedField = nil
        Task { await authService.signUp(name: name, email: email) }
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                let email = credential.email
                Task {
                    await authService.signInWithApple(
                        name: fullName.isEmpty ? nil : fullName,
                        email: email
                    )
                }
            }
        case .failure(let error):
            print("[SignUp] Apple sign in failed: \(error.localizedDescription)")
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
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthService.shared)
}

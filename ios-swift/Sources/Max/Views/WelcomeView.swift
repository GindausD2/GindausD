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
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 1.00, green: 1.00, blue: 1.00), location: 0.0),
                .init(color: Color(red: 0.97, green: 0.95, blue: 1.00), location: 0.5),
                .init(color: Color(red: 0.93, green: 0.89, blue: 1.00), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var ambientBlobs: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#7C3AED").opacity(0.07))
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: -90, y: -210)
            Circle()
                .fill(Color(hex: "#4F46E5").opacity(0.05))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 110, y: 280)
            Circle()
                .fill(Color(hex: "#C084FC").opacity(0.04))
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
                    .fill(currentPage == i ? Color(hex: "#7C3AED") : Color(hex: "#7C3AED").opacity(0.25))
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
                    Capsule().strokeBorder(Color(hex: "#7C3AED").opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Shared Apple Sign-In Handler

private func appleSignInHandler(authService: AuthService) -> (Result<ASAuthorization, Error>) -> Void {
    return { result in
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else { return }
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        Task {
            await authService.signInWithApple(
                idToken: idToken,
                name: fullName.isEmpty ? nil : fullName
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
                            colors: [Color(hex: "#7C3AED"), Color(hex: "#4F46E5")],
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
        .shadow(color: Color(hex: "#7C3AED").opacity(0.35), radius: 14, x: 0, y: 5)
        .shadow(color: Color(hex: "#7C3AED").opacity(0.12), radius: 30, x: 0, y: 10)
        .disabled(isLoading || isDisabled)
        .opacity(isDisabled ? 0.55 : 1.0)
    }
}

// MARK: - Login Page

private struct LoginPage: View {
    var onNavigateToWelcome: () -> Void
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 48)

                VStack(spacing: 8) {
                    Text("Welcome back")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Sign in to continue with Max")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)

                GlassCard(
                    cornerRadius: 26,
                    depth: .ultraThin,
                    padding: EdgeInsets(top: 26, leading: 22, bottom: 26, trailing: 22)
                ) {
                    VStack(spacing: 18) {
                        if let err = authService.authError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        SignInWithAppleButton(
                            onRequest: { $0.requestedScopes = [.fullName, .email] },
                            onCompletion: appleSignInHandler(authService: authService)
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                        .disabled(authService.isLoading)
                    }
                }
                .padding(.horizontal, 22)

                Button { onNavigateToWelcome() } label: {
                    HStack(spacing: 5) {
                        Text("New to Max?")
                            .foregroundStyle(.secondary)
                        Text("Get started →")
                            .foregroundStyle(Color(hex: "#7C3AED"))
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
                depth: .ultraThin,
                padding: EdgeInsets(top: 22, leading: 28, bottom: 22, trailing: 28)
            ) {
                VStack(spacing: 12) {
                    MaxLogoView(color: Color(hex: "#7C3AED"), width: 180)
                        .padding(.bottom, 2)
                    Text("Your AI personal assistant")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Powered by Claude")
                        .font(.caption)
                        .foregroundStyle(Color.secondary.opacity(0.7))
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

            Button {
                showDemoOnboarding = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                    Text("Try Demo")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 48)

                VStack(spacing: 8) {
                    Text("Create account")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Sign up with Apple to get started")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)

                GlassCard(
                    cornerRadius: 26,
                    depth: .ultraThin,
                    padding: EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22)
                ) {
                    VStack(spacing: 16) {
                        if let err = authService.authError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        SignInWithAppleButton(
                            onRequest: { $0.requestedScopes = [.fullName, .email] },
                            onCompletion: appleSignInHandler(authService: authService)
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                        .disabled(authService.isLoading)
                    }
                }
                .padding(.horizontal, 22)

                Button { onBack() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left").font(.caption)
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 22)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize)
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

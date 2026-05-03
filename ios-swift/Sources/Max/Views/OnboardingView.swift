import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0
    private let total = 6

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.04, blue: 0.02).ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    if page < total - 1 {
                        Button("Skip") { onComplete() }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.40))
                            .padding(.trailing, 24)
                            .padding(.top, 16)
                    } else {
                        Spacer().frame(height: 44 + 16)
                    }
                }

                // Pages
                TabView(selection: $page) {
                    WelcomePage()         .tag(0)
                    VoicePage()           .tag(1)
                    DynamicIslandPage()   .tag(2)
                    ActionButtonPage()    .tag(3)
                    WidgetPage()          .tag(4)
                    GetStartedPage()      .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: page)

                // Dot indicator
                HStack(spacing: 8) {
                    ForEach(0..<total, id: \.self) { i in
                        Capsule()
                            .fill(i == page
                                  ? Color(red: 1.00, green: 0.55, blue: 0.05)
                                  : Color.white.opacity(0.22))
                            .frame(width: i == page ? 28 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.bottom, 28)

                // CTA button
                Button {
                    if page < total - 1 {
                        withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(page == total - 1 ? "Start Talking to Max" : "Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.55, blue: 0.05),
                                    Color(red: 0.90, green: 0.28, blue: 0.00)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .shadow(color: Color(red: 1.00, green: 0.45, blue: 0.00).opacity(0.5),
                                radius: 18, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
    }
}

// MARK: - Shared page layout

private struct PageLayout<Art: View>: View {
    @ViewBuilder var art: () -> Art
    let title: String
    let body: String
    var tip: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            art()
                .padding(.bottom, 52)

            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(body)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 36)
                .padding(.top, 14)

            if let tip {
                HStack(spacing: 7) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                    Text(tip)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color(red: 1.00, green: 0.60, blue: 0.10).opacity(0.85))
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    Color(red: 1.00, green: 0.55, blue: 0.05).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .padding(.top, 22)
                .padding(.horizontal, 36)
            }

            Spacer()
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        PageLayout(
            art: {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.00, green: 0.45, blue: 0.00).opacity(0.12))
                        .frame(width: 200, height: 200)
                    OrbView(state: .idle, size: 120)
                }
            },
            title: "Meet Max",
            body: "Your AI personal assistant that lives right inside your iPhone. Talk naturally, get things done."
        )
    }
}

// MARK: - Page 2: Voice

private struct VoicePage: View {
    @State private var pulse = false

    var body: some View {
        PageLayout(
            art: {
                ZStack {
                    ForEach([1, 2, 3], id: \.self) { i in
                        Circle()
                            .strokeBorder(
                                Color(red: 1.00, green: 0.55, blue: 0.05)
                                    .opacity(pulse ? 0.0 : Double(4 - i) * 0.12),
                                lineWidth: 1.5
                            )
                            .frame(width: CGFloat(100 + i * 36), height: CGFloat(100 + i * 36))
                            .scaleEffect(pulse ? 1.6 : 1.0)
                            .animation(
                                .easeOut(duration: 1.4)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.45),
                                value: pulse
                            )
                    }
                    OrbView(state: .listening, size: 100)
                }
                .onAppear { pulse = true }
            },
            title: "Press the Orb to Talk",
            body: "Tap the orange orb and speak. Max listens, thinks, then answers out loud. Ask anything — book a flight, check your calendar, set a reminder.",
            tip: "Tap again while Max is speaking to stop it."
        )
    }
}

// MARK: - Page 3: Dynamic Island

private struct DynamicIslandPage: View {
    @State private var glow = false

    var body: some View {
        PageLayout(
            art: {
                ZStack(alignment: .top) {
                    // Phone outline
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1.5)
                        .frame(width: 160, height: 280)

                    // Dynamic Island pill
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black)
                        .frame(width: 130, height: 42)
                        .overlay(
                            HStack(spacing: 10) {
                                OrbView(state: .thinking, size: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Max")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("Thinking…")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.05))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                        )
                        .shadow(
                            color: Color(red: 1.00, green: 0.45, blue: 0.00).opacity(glow ? 0.55 : 0.20),
                            radius: glow ? 18 : 8
                        )
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)
                        .padding(.top, 14)
                }
                .onAppear { glow = true }
            },
            title: "Always With You",
            body: "Max lives in your Dynamic Island at the top of the screen. While you're using other apps, Max quietly shows what it's doing and is always one tap away.",
            tip: "Works on iPhone 14 Pro and later."
        )
    }
}

// MARK: - Page 4: Action Button

private struct ActionButtonPage: View {
    @State private var pressed = false

    var body: some View {
        PageLayout(
            art: {
                ZStack {
                    // Phone body
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .fill(Color(white: 0.10))
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1.5)
                        .frame(width: 150, height: 280)

                    // Action button (left side, upper)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(pressed
                              ? Color(red: 1.00, green: 0.55, blue: 0.05)
                              : Color(white: 0.28))
                        .frame(width: 7, height: 36)
                        .offset(x: -80, y: -56)
                        .animation(.easeInOut(duration: 0.15), value: pressed)
                        .shadow(
                            color: Color(red: 1.00, green: 0.45, blue: 0.00)
                                .opacity(pressed ? 0.8 : 0),
                            radius: 12
                        )

                    // Label
                    VStack(spacing: 6) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.05))
                        Text("Activate Max")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    .offset(y: 20)
                }
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
                        pressed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { pressed = false }
                    }
                }
            },
            title: "One Press to Activate",
            body: "Set your Action Button to launch Max instantly. One press — Max starts listening right away, no unlocking needed.",
            tip: "Settings → Action Button → Shortcut → \"Activate Max\""
        )
    }
}

// MARK: - Page 5: Widget

private struct WidgetPage: View {
    var body: some View {
        PageLayout(
            art: {
                HStack(spacing: 16) {
                    // Small widget
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(red: 0.07, green: 0.05, blue: 0.03))
                        .frame(width: 148, height: 148)
                        .overlay(
                            VStack(spacing: 7) {
                                OrbView(state: .idle, size: 56)
                                Text("Max")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Tap to talk")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(
                                        Color(red: 1.00, green: 0.55, blue: 0.05).opacity(0.85)
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .shadow(
                            color: Color(red: 1.00, green: 0.45, blue: 0.00).opacity(0.35),
                            radius: 24, x: 0, y: 8
                        )

                    // Lock screen widget
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(white: 0.12))
                            .frame(width: 60, height: 60)
                            .overlay(OrbView(state: .idle, size: 36))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                            )

                        Text("Lock Screen")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                }
            },
            title: "Max on Your Home Screen",
            body: "Add the Max widget and start a conversation with one tap — no unlocking, no searching.",
            tip: "Long press home screen → tap + → search \"Max\""
        )
    }
}

// MARK: - Page 6: Get Started

private struct GetStartedPage: View {
    @State private var glow = false

    var body: some View {
        PageLayout(
            art: {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.45, blue: 0.00).opacity(glow ? 0.25 : 0.10),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 130
                            )
                        )
                        .frame(width: 260, height: 260)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glow)

                    OrbView(state: .idle, size: 130)
                }
                .onAppear { glow = true }
            },
            title: "You're All Set",
            body: "Press the orb and say anything. Max handles the rest."
        )
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}

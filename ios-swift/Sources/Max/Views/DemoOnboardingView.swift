import SwiftUI

// MARK: - DemoOnboardingView
//
// Three-slide liquid glass onboarding shown before the demo session:
//   Slide 1 — Name + Gender
//   Slide 2 — AI Voice preference (Male / Female)
//   Slide 3 — Summary + "Start Demo" CTA

struct DemoOnboardingView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 0
    @State private var name: String = ""
    @State private var gender: DemoGender = .preferNotToSay
    @State private var voice: DemoVoice = .female
    @State private var isLaunching: Bool = false

    // Slide count
    private let totalSteps = 3

    var body: some View {
        ZStack {
            // Same deep violet gradient as WelcomeView
            demoBackground.ignoresSafeArea()
            ambientBlobs

            VStack(spacing: 0) {
                // ── Progress dots ───────────────────────────────────────────
                progressIndicator
                    .padding(.top, 56)
                    .padding(.bottom, 12)

                // ── Slides ──────────────────────────────────────────────────
                TabView(selection: $step) {
                    Slide1(name: $name, gender: $gender, onNext: advance)
                        .tag(0)
                    Slide2(voice: $voice, onNext: advance)
                        .tag(1)
                    Slide3(name: name, voice: voice, isLaunching: isLaunching, onStart: launchDemo)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Background

    private var demoBackground: some View {
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
                .frame(width: 340)
                .blur(radius: 80)
                .offset(x: -80, y: -220)
                .allowsHitTesting(false)
            Circle()
                .fill(Color(hex: "#4F46E5").opacity(0.18))
                .frame(width: 260)
                .blur(radius: 70)
                .offset(x: 120, y: 300)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Progress indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(step >= i ? Color.white : Color.white.opacity(0.28))
                    .frame(width: step == i ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.32, dampingFraction: 0.72), value: step)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(.white.opacity(0.20), lineWidth: 0.5))
        )
    }

    // MARK: - Navigation

    private func advance() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = min(step + 1, totalSteps - 1)
        }
    }

    private func launchDemo() {
        guard !isLaunching else { return }
        isLaunching = true
        Task {
            await authService.startDemo(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                voice: voice.rawValue
            )
            isLaunching = false
            dismiss()
        }
    }
}

// MARK: - Slide 1: Name + Gender ──────────────────────────────────────────────

private struct Slide1: View {
    @Binding var name: String
    @Binding var gender: DemoGender
    var onNext: () -> Void

    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                // Header
                VStack(spacing: 10) {
                    Text("What should Max\ncall you?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Personalise your demo experience")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.60))
                }
                .padding(.bottom, 32)

                // Glass card
                DemoGlassCard {
                    VStack(spacing: 22) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOUR NAME")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.55))
                                .kerning(0.8)

                            TextField("e.g. Alex", text: $name)
                                .focused($nameFocused)
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                                .tint(Color(hex: "#A78BFA"))
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(demoFieldBackground)
                        }

                        // Gender picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("GENDER")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.55))
                                .kerning(0.8)

                            HStack(spacing: 10) {
                                ForEach(DemoGender.allCases, id: \.self) { g in
                                    DemoGenderPill(label: g.label, isSelected: gender == g) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            gender = g
                                        }
                                    }
                                }
                            }
                        }

                        // Continue
                        DemoPrimaryButton(
                            title: "Continue →",
                            isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            nameFocused = false
                            onNext()
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { nameFocused = true } }
    }
}

// MARK: - Slide 2: Voice ───────────────────────────────────────────────────────

private struct Slide2: View {
    @Binding var voice: DemoVoice
    var onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                // Header
                VStack(spacing: 10) {
                    Text("How should\nMax sound?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Choose the voice Max will use to reply")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.60))
                }
                .padding(.bottom, 32)

                // Glass card
                DemoGlassCard {
                    VStack(spacing: 16) {
                        ForEach(DemoVoice.allCases, id: \.self) { v in
                            DemoVoiceCard(option: v, isSelected: voice == v) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    voice = v
                                }
                            }
                        }

                        DemoPrimaryButton(title: "Continue →") { onNext() }
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Slide 3: Ready ───────────────────────────────────────────────────────

private struct Slide3: View {
    var name: String
    var voice: DemoVoice
    var isLaunching: Bool
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Orb
            OrbView(state: .idle, size: 110)
                .padding(.bottom, 28)
                .shadow(color: Color(hex: "#7C3AED").opacity(0.40), radius: 40)

            DemoGlassCard {
                VStack(spacing: 18) {
                    // Summary header
                    VStack(spacing: 6) {
                        Text("You're all set\(name.isEmpty ? "" : ", \(name)")!")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("Max is ready to assist you")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    // Summary pills
                    HStack(spacing: 12) {
                        SummaryPill(icon: "person.fill", label: name.isEmpty ? "Guest" : name)
                        SummaryPill(icon: voice.symbolName, label: voice.label)
                    }
                    .frame(maxWidth: .infinity)

                    // Divider
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.18), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)

                    // CTA
                    DemoPrimaryButton(
                        title: isLaunching ? "Starting…" : "Start exploring Max",
                        isLoading: isLaunching
                    ) {
                        onStart()
                    }

                    Text("All features included · No account required")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.40))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Supporting Views ─────────────────────────────────────────────────────

/// Frosted glass container card used on each demo slide
private struct DemoGlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            // Material base
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.thinMaterial)
            // White tint
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
            // Specular top highlight
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.45)
                        )
                    )
                    .frame(height: 60)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            // Gradient border
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.55), location: 0.0),
                            .init(color: .white.opacity(0.18), location: 0.40),
                            .init(color: .white.opacity(0.04), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        }
        .overlay(content().padding(24))
        .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 10)
        .shadow(color: Color(hex: "#7C3AED").opacity(0.12), radius: 40, x: 0, y: 16)
    }
}

/// Gender selection pill
private struct DemoGenderPill: View {
    var label: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color(hex: "#7C3AED") : .white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? .white : Color.white.opacity(0.10))
                        if !isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.14), .clear],
                                        startPoint: .top, endPoint: .center
                                    )
                                )
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.25), lineWidth: 0.75)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .shadow(
            color: isSelected ? Color(hex: "#7C3AED").opacity(0.30) : .clear,
            radius: 8, x: 0, y: 3
        )
    }
}

/// Voice selection card (large tap target with waveform icon)
private struct DemoVoiceCard: View {
    var option: DemoVoice
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                            ? LinearGradient(
                                colors: [Color(hex: "#7C3AED"), Color(hex: "#4F46E5")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle().strokeBorder(
                                isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.15),
                                lineWidth: 0.75
                            )
                        )
                    Image(systemName: option.symbolName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: isSelected)
                }
                .shadow(
                    color: isSelected ? Color(hex: "#7C3AED").opacity(0.50) : .clear,
                    radius: 12, x: 0, y: 4
                )

                // Labels
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(option.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                // Selection check
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#7C3AED") : Color.white.opacity(0.12))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(
                            isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.20),
                            lineWidth: 0.75
                        ))
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.14), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            isSelected
                            ? LinearGradient(
                                colors: [Color(hex: "#A78BFA").opacity(0.80), Color(hex: "#7C3AED").opacity(0.30)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [.white.opacity(0.30), .white.opacity(0.06)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: isSelected ? 1.5 : 0.75
                        )
                }
            )
        }
        .buttonStyle(.plain)
        .shadow(
            color: isSelected ? Color(hex: "#7C3AED").opacity(0.22) : .clear,
            radius: 14, x: 0, y: 5
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isSelected)
    }
}

/// Compact summary pill used on slide 3
private struct SummaryPill: View {
    var icon: String
    var label: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#A78BFA"))
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule().fill(
                    LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center)
                )
                Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.75)
            }
        )
    }
}

/// Primary CTA button with violet gradient + glass spec
private struct DemoPrimaryButton: View {
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
                            startPoint: .topLeading, endPoint: .bottomTrailing
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
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
        )
        .foregroundStyle(.white)
        .shadow(color: Color(hex: "#7C3AED").opacity(0.50), radius: 12, x: 0, y: 5)
        .shadow(color: Color(hex: "#7C3AED").opacity(0.20), radius: 28, x: 0, y: 10)
        .disabled(isLoading || isDisabled)
        .opacity(isDisabled ? 0.50 : 1.0)
    }
}

// MARK: - Glass text field background helper

private var demoFieldBackground: some View {
    ZStack {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.07))
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
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 1.0
            )
    }
}

// MARK: - Enums ────────────────────────────────────────────────────────────────

enum DemoGender: String, CaseIterable {
    case male         = "male"
    case female       = "female"
    case preferNotToSay = "prefer_not"

    var label: String {
        switch self {
        case .male:           return "Male"
        case .female:         return "Female"
        case .preferNotToSay: return "Other"
        }
    }
}

enum DemoVoice: String, CaseIterable {
    case female = "female"
    case male   = "male"

    var label: String {
        switch self {
        case .female: return "Warm & Feminine"
        case .male:   return "Clear & Masculine"
        }
    }

    var description: String {
        switch self {
        case .female: return "Friendly, warm, expressive tone"
        case .male:   return "Calm, articulate, professional tone"
        }
    }

    var symbolName: String {
        switch self {
        case .female: return "waveform"
        case .male:   return "waveform.path"
        }
    }
}

// MARK: - Preview

#Preview {
    DemoOnboardingView()
        .environmentObject(AuthService.shared)
}

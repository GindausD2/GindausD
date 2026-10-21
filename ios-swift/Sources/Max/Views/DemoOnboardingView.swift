import SwiftUI

/// A guest can explore before using Apple sign-in or choosing a subscription.
struct DemoOnboardingView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var voice: DemoVoice = .female
    @State private var isLaunching = false
    @State private var showPersonalisation = false

    var body: some View {
        ZStack {
            CompanionCanvas()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.medium))
                                .frame(width: 44, height: 44)
                                .glassCard(cornerRadius: 22, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close demo welcome")
                        Spacer()
                        CompanionWordmark()
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .disabled(isLaunching)

                    EntryHero(eyebrow: "SEVEN DAYS, A LITTLE LIGHTER", title: "Say hello\nto your Max.", subtitle: "A little time together.\nSee how Max fits into your day.", orbSize: 104)

                    VStack(alignment: .leading, spacing: 18) {
                        EntryFeatureRow(icon: "bubble.left.and.bubble.right", title: "Talk it through", detail: "Ideas, questions and everyday plans.")
                        EntryFeatureRow(icon: "bookmark", title: "Keep a little thought", detail: "Save something you want to remember.")
                        EntryFeatureRow(icon: "sun.horizon", title: "Make space for your day", detail: "Start with one small next step.")
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 28)

                    DisclosureGroup(isExpanded: $showPersonalisation) {
                        VStack(alignment: .leading, spacing: 16) {
                            TextField("What should Max call you? (optional)", text: $name)
                                .textContentType(.givenName)
                                .textInputAutocapitalization(.words)
                                .padding(14)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                            Picker("Max’s voice", selection: $voice) {
                                ForEach(DemoVoice.allCases, id: \.self) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                        .padding(.top, 14)
                    } label: {
                        Label("Make it yours · optional", systemImage: "slider.horizontal.3")
                            .font(.subheadline)
                    }
                    .tint(Color(hex: "#416F84"))
                    .disabled(isLaunching)

                    VStack(spacing: 14) {
                        EntryPrimaryButton(title: isLaunching ? "Getting your space ready…" : "Start my 7-day demo", isLoading: isLaunching, action: launchDemo)
                        Text("No Apple sign-in. No payment.\nYour demo ends after 7 days.")
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .interactiveDismissDisabled(isLaunching)
        .alert("Demo unavailable", isPresented: Binding(
            get: { authService.authError != nil },
            set: { if !$0 { authService.authError = nil } }
        )) { Button("OK") { authService.authError = nil } }
        message: { Text(authService.authError ?? "Please try again.") }
    }

    private func launchDemo() {
        guard !isLaunching else { return }
        isLaunching = true
        Task {
            let started = await authService.startDemo(name: name.trimmingCharacters(in: .whitespacesAndNewlines), voice: voice.rawValue)
            isLaunching = false
            if started { dismiss() }
        }
    }
}

private struct EntryFeatureRow: View {
    var icon: String
    var title: String
    var detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color(hex: "#57879B"))
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

enum DemoVoice: String, CaseIterable {
    case female = "female"
    case male = "male"
    var label: String { self == .female ? "Warm & Feminine" : "Clear & Masculine" }
}

#Preview {
    DemoOnboardingView().environmentObject(AuthService.shared)
}

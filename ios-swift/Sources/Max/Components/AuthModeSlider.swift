import SwiftUI

enum AuthEntryMode: String, CaseIterable {
    case login = "Login"
    case signUp = "Sign Up"

    var page: Int { self == .login ? 0 : 2 }
}

struct AuthModeSlider: View {
    @Binding var selection: AuthEntryMode
    @GestureState private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        GeometryReader { geometry in
            let travel = max(0, (geometry.size.width - 10) / 2)
            let origin: CGFloat = selection == .login ? 0 : travel
            let position = min(travel, max(0, origin + dragOffset))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        colors: [.white.opacity(colorScheme == .dark ? 0.16 : 0.82), Color(hex: "#B8DEED").opacity(0.42)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.65), lineWidth: 0.75))
                    .shadow(color: Color(hex: "#315F75").opacity(0.12), radius: 8, x: 0, y: 3)
                    .frame(width: travel, height: 50)
                    .offset(x: 5 + position)

                HStack(spacing: 0) {
                    modeButton(.login, symbol: "chevron.left")
                    modeButton(.signUp, symbol: "chevron.right")
                }
                .padding(5)
            }
            .frame(height: 60)
            .contentShape(Capsule())
            .simultaneousGesture(DragGesture(minimumDistance: 8)
                .updating($dragOffset) { value, offset, _ in offset = value.translation.width }
                .onEnded { value in
                    guard isEnabled else { return }
                    select(origin + value.predictedEndTranslation.width > travel / 2 ? .signUp : .login)
                })
        }
        .frame(height: 60)
        .glassCard(cornerRadius: 30, depth: .ultraThin, interactive: true)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .opacity(isEnabled ? 1 : 0.55)
        .allowsHitTesting(isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Login or sign up")
        .accessibilityValue(selection.rawValue)
        .accessibilityHint("Adjust to switch between Login and Sign Up.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .decrement: select(.login)
            case .increment: select(.signUp)
            @unknown default: break
            }
        }
    }

    private func modeButton(_ mode: AuthEntryMode, symbol: String) -> some View {
        Button { select(mode) } label: {
            HStack(spacing: 7) {
                if mode == .login { Image(systemName: symbol).font(.caption.weight(.semibold)) }
                Text(mode.rawValue).font(.subheadline.weight(.semibold))
                if mode == .signUp { Image(systemName: symbol).font(.caption.weight(.semibold)) }
            }
            .foregroundStyle(selection == mode ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func select(_ mode: AuthEntryMode) {
        guard isEnabled else { return }
        selection = mode
    }
}

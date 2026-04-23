import SwiftUI

// MARK: - Orb State

enum OrbState {
    case idle
    case listening
    case thinking
    case speaking

    var colors: [Color] {
        switch self {
        case .idle:
            return [
                Color(red: 1.00, green: 0.55, blue: 0.05),
                Color(red: 0.95, green: 0.35, blue: 0.00),
                Color(red: 1.00, green: 0.70, blue: 0.10)
            ]
        case .listening:
            return [
                Color(red: 1.00, green: 0.45, blue: 0.00),
                Color(red: 0.90, green: 0.25, blue: 0.00),
                Color(red: 1.00, green: 0.60, blue: 0.10)
            ]
        case .thinking:
            return [
                Color(red: 0.85, green: 0.42, blue: 0.00),
                Color(red: 0.70, green: 0.28, blue: 0.00),
                Color(red: 0.95, green: 0.55, blue: 0.10)
            ]
        case .speaking:
            return [
                Color(red: 1.00, green: 0.50, blue: 0.00),
                Color(red: 0.95, green: 0.28, blue: 0.00),
                Color(red: 1.00, green: 0.65, blue: 0.05)
            ]
        }
    }

    var pulseSpeed: Double {
        switch self {
        case .idle:      return 2.8
        case .listening: return 0.6
        case .thinking:  return 1.4
        case .speaking:  return 0.5
        }
    }

    var pulseScale: CGFloat {
        switch self {
        case .idle:      return 1.08
        case .listening: return 1.18
        case .thinking:  return 1.12
        case .speaking:  return 1.22
        }
    }
}

// MARK: - OrbView

struct OrbView: View {
    var state: OrbState = .idle
    var size: CGFloat = 128

    @State private var pulsing: Bool = false
    @State private var rotation: Double = 0
    @State private var hapticTimer: Timer? = nil

    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        ZStack {
            // Outer glow / pulse ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [state.colors[0].opacity(0.35), Color.clear],
                        center: .center,
                        startRadius: size * 0.35,
                        endRadius: size * 0.65
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .scaleEffect(pulsing ? state.pulseScale : 1.0)
                .opacity(pulsing ? 0.7 : 0.3)
                .animation(
                    .easeInOut(duration: state.pulseSpeed)
                    .repeatForever(autoreverses: true),
                    value: pulsing
                )

            // Main orb body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            state.colors[0],
                            state.colors[1],
                            state.colors[2].opacity(0.85)
                        ],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    // Rotating shimmer overlay
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.0)
                                ],
                                center: .center,
                                startAngle: .degrees(rotation),
                                endAngle: .degrees(rotation + 360)
                            )
                        )
                )
                .overlay(
                    // Highlight specular
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), Color.clear],
                                startPoint: .init(x: 0.25, y: 0.15),
                                endPoint: .init(x: 0.6, y: 0.55)
                            )
                        )
                        .frame(width: size * 0.42, height: size * 0.28)
                        .offset(x: -size * 0.12, y: -size * 0.18)
                )
                .shadow(color: state.colors[0].opacity(0.6), radius: size * 0.22, x: 0, y: size * 0.08)
                .shadow(color: state.colors[1].opacity(0.35), radius: size * 0.4, x: 0, y: 0)
        }
        .onAppear {
            haptic.prepare()
            pulsing = true
            withAnimation(
                .linear(duration: 6)
                .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
        }
        .onChange(of: state) { _, newState in
            pulsing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pulsing = true
            }
            updateHaptics(for: newState)
        }
        .onDisappear { stopHaptics() }
    }

    // MARK: - Haptics

    private func updateHaptics(for state: OrbState) {
        stopHaptics()
        guard state == .speaking else { return }
        haptic.prepare()
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { _ in
            haptic.impactOccurred(intensity: 0.55)
        }
    }

    private func stopHaptics() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
}

#Preview {
    VStack(spacing: 32) {
        HStack(spacing: 24) {
            OrbView(state: .idle, size: 80)
            OrbView(state: .listening, size: 80)
            OrbView(state: .thinking, size: 80)
            OrbView(state: .speaking, size: 80)
        }
        OrbView(state: .speaking, size: 128)
    }
    .padding(40)
    .background(Color(red: 0.12, green: 0.08, blue: 0.05))
}

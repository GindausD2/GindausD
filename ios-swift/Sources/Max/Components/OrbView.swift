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
                Color(red: 1.0, green: 0.84, blue: 0.0),
                Color(red: 1.0, green: 0.65, blue: 0.0),
                Color(red: 1.0, green: 0.45, blue: 0.1)
            ]
        case .listening:
            return [
                Color(red: 0.6, green: 0.2, blue: 0.9),
                Color(red: 0.4, green: 0.1, blue: 0.8),
                Color(red: 0.8, green: 0.4, blue: 1.0)
            ]
        case .thinking:
            return [
                Color(red: 0.5, green: 0.5, blue: 0.55),
                Color(red: 0.35, green: 0.35, blue: 0.4),
                Color(red: 0.65, green: 0.65, blue: 0.7)
            ]
        case .speaking:
            return [
                Color(red: 0.55, green: 0.2, blue: 0.85),
                Color(red: 0.35, green: 0.05, blue: 0.75),
                Color(red: 0.75, green: 0.35, blue: 0.95)
            ]
        }
    }

    var pulseSpeed: Double {
        switch self {
        case .idle: return 2.8
        case .listening: return 0.6
        case .thinking: return 1.4
        case .speaking: return 0.7
        }
    }

    var pulseScale: CGFloat {
        switch self {
        case .idle: return 1.08
        case .listening: return 1.18
        case .thinking: return 1.12
        case .speaking: return 1.20
        }
    }
}

// MARK: - OrbView

struct OrbView: View {
    var state: OrbState = .idle
    var size: CGFloat = 128

    @State private var pulsing: Bool = false
    @State private var rotation: Double = 0

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
            pulsing = true
            withAnimation(
                .linear(duration: 6)
                .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
        }
        .onChange(of: state) { _, _ in
            // Re-trigger pulse animation on state change
            pulsing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pulsing = true
            }
        }
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
        OrbView(state: .listening, size: 128)
    }
    .padding(40)
    .background(Color(red: 0.18, green: 0.11, blue: 0.41))
}

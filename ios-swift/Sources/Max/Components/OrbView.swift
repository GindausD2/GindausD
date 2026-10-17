import SwiftUI

enum OrbState { case idle, listening, thinking, speaking }

/// A glacier-blue glass sphere. Only active voice states animate, so the resting
/// screen stays quiet and does not run a continuous rendering loop.
struct OrbView: View {
    var state: OrbState = .idle
    var size: CGFloat = 128
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: state == .idle || reduceMotion)) { context in
            OrbFrame(state: state, size: size, time: context.date.timeIntervalSinceReferenceDate, reduceMotion: reduceMotion)
        }
        .accessibilityHidden(true)
    }
}

private struct OrbFrame: View {
    let state: OrbState
    let size: CGFloat
    let time: TimeInterval
    let reduceMotion: Bool
    private let heights: [CGFloat] = [0.24, 0.43, 0.64, 0.43, 0.24]

    private var moving: Bool { state != .idle && !reduceMotion }
    private var pulse: CGFloat {
        guard moving else { return 0 }
        return CGFloat((sin(time * (state == .speaking ? 5 : 3)) + 1) / 2)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#ADDCEC").opacity(0.4), .clear], center: .center, startRadius: size * 0.3, endRadius: size * 0.71))
                .scaleEffect(0.97 + pulse * 0.06)
            Circle().strokeBorder(Color(hex: "#A8CDDC").opacity(0.13), lineWidth: 0.6)
                .frame(width: size * 1.27, height: size * 1.27)
            sphere
        }
        .frame(width: size * 1.42, height: size * 1.42)
    }

    private var sphere: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: "#F3FCFF"), Color(hex: "#C9EAF5"), Color(hex: "#82BDD3"), Color(hex: "#427E9B")], center: .init(x: 0.25, y: 0.12), startRadius: 0, endRadius: size * 0.93))
            .overlay { liquidFolds }
            .overlay(alignment: .topLeading) {
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.64, height: size * 0.28)
                    .rotationEffect(.degrees(-35))
                    .offset(x: size * 0.01, y: size * 0.09)
                    .blur(radius: size * 0.025)
            }
            .overlay {
                if state == .speaking || state == .listening { waveform }
                if state == .thinking { ProgressView().tint(Color(hex: "#214E63")) }
            }
            .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.08), .white.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .clipShape(Circle())
            .frame(width: size, height: size)
            .scaleEffect(1 + pulse * (state == .speaking ? 0.035 : 0.018))
            .shadow(color: Color(hex: "#6BA7BE").opacity(0.18), radius: size * 0.15, y: size * 0.12)
    }

    private var liquidFolds: some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: "#356D8D").opacity(0.62), Color(hex: "#A7D6E7").opacity(0.2), .white.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 1.15, height: size * 0.48)
                .rotationEffect(.degrees(-38 + Double(pulse) * 7))
                .offset(x: size * 0.18, y: size * 0.23)
                .blur(radius: size * 0.025)
            Ellipse()
                .stroke(LinearGradient(colors: [.clear, .white.opacity(0.9), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: size * 0.035)
                .frame(width: size * 0.96, height: size * 0.64)
                .rotationEffect(.degrees(-40 + Double(pulse) * 7))
                .offset(x: size * 0.18, y: size * 0.17)
                .blur(radius: size * 0.025)
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.7), Color(hex: "#CDEFFA").opacity(0.1)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.58, height: size * 0.85)
                .rotationEffect(.degrees(34 - Double(pulse) * 5))
                .offset(x: -size * 0.34, y: size * 0.24)
                .blur(radius: size * 0.035)
        }
    }

    private var waveform: some View {
        HStack(spacing: size * 0.033) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule().fill(Color(hex: "#214E63"))
                    .frame(width: max(3, size * 0.027), height: size * heights[index] * 0.5)
                    .scaleEffect(x: 1, y: barScale(index))
            }
        }
    }

    private func barScale(_ index: Int) -> CGFloat {
        guard moving else { return 1 }
        return 0.85 + CGFloat(sin(time * (5 + Double(index) * 0.7) + Double(index))) * 0.35
    }
}

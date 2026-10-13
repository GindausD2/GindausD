import SwiftUI

enum OrbState { case idle, listening, thinking, speaking }

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
        let frequency: Double = state == .speaking ? 5 : 3
        return CGFloat((sin(time * frequency) + 1) / 2)
    }
    var body: some View {
        ZStack { halo; sphere }
            .frame(width: size * 1.42, height: size * 1.42)
    }
    private var halo: some View {
        Circle().fill(RadialGradient(colors: [Color(hex: "#B9E5F3").opacity(0.34), Color(hex: "#C2E7F4").opacity(0)], center: .center, startRadius: size * 0.25, endRadius: size * 0.71))
            .frame(width: size * 1.42, height: size * 1.42)
            .scaleEffect(0.94 + pulse * 0.1)
    }
    private var sphere: some View {
        Circle().fill(RadialGradient(colors: [Color(hex: "#EDFAFF"), Color(hex: "#BCE8F5"), Color(hex: "#78BED9"), Color(hex: "#4F96B5")], center: .init(x: 0.28, y: 0.20), startRadius: 0, endRadius: size * 0.9))
            .overlay { refraction }
            .overlay(alignment: .topLeading) { reflection }
            .overlay {
                if state == .speaking || state == .listening { waveform }
                if state == .thinking { ProgressView().tint(Color(hex: "#315E73")) }
            }
            .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 0.75))
            .clipShape(Circle())
            .frame(width: size, height: size)
            .scaleEffect(1 + pulse * (state == .speaking ? 0.035 : 0.018))
            .shadow(color: Color(hex: "#6CAEC8").opacity(0.22), radius: size * 0.20, x: 0, y: size * 0.10)
    }
    private var refraction: some View {
        Ellipse()
            .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.32), Color(hex: "#DAF5FC").opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size * 0.88, height: size * 0.67)
            .rotationEffect(.degrees(-36 + Double(pulse) * 8))
            .offset(x: size * 0.24, y: size * 0.27)
            .blur(radius: size * 0.035)
    }
    private var reflection: some View {
        Ellipse().fill(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.48, height: size * 0.30)
            .rotationEffect(.degrees(-35 + Double(pulse) * 5))
            .offset(x: size * 0.12, y: size * 0.09)
    }
    private var waveform: some View {
        HStack(spacing: size * 0.033) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule().fill(Color(hex: "#315E73"))
                    .frame(width: max(3, size * 0.027), height: size * heights[index] * 0.5)
                    .scaleEffect(x: 1, y: barScale(index))
            }
        }
    }
    private func barScale(_ index: Int) -> CGFloat {
        guard moving, state == .speaking || state == .listening else { return 1 }
        let frequency = 5 + Double(index) * 0.7
        return 0.85 + CGFloat(sin(time * frequency + Double(index))) * 0.35
    }
}

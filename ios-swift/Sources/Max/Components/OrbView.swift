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
        ZStack { halo; glassRing; sphere }
            .frame(width: size * 1.42, height: size * 1.42)
    }
    private var halo: some View {
        Circle().fill(Color(hex: "#C2E7F4").opacity(0.12))
            .overlay(Circle().strokeBorder(.white.opacity(0.65), lineWidth: 1))
            .frame(width: size * 1.42, height: size * 1.42)
            .scaleEffect(0.94 + pulse * 0.1)
    }
    private var glassRing: some View {
        Circle().fill(.white.opacity(0.18))
            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1))
            .frame(width: size * 1.21, height: size * 1.21)
    }
    private var sphere: some View {
        Circle().fill(LinearGradient(colors: [Color(hex: "#F0FBFF"), Color(hex: "#BDE5F4"), Color(hex: "#79B9D4"), Color(hex: "#538FAA")], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .topLeading) { reflection }
            .overlay { waveform }
            .overlay(Circle().strokeBorder(.white.opacity(0.95), lineWidth: 1))
            .frame(width: size, height: size)
            .scaleEffect(1 + pulse * (state == .speaking ? 0.035 : 0.018))
            .shadow(color: Color(hex: "#467B94").opacity(0.2), radius: 20, x: 0, y: 10)
    }
    private var reflection: some View {
        Ellipse().fill(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.66, height: size * 0.30)
            .rotationEffect(.degrees(-22))
            .offset(x: size * 0.13, y: size * 0.08)
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

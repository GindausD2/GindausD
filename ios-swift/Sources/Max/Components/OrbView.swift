import SwiftUI

enum OrbState { case idle, listening, thinking, speaking }

struct OrbView: View {
    var state: OrbState = .idle
    var size: CGFloat = 128
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let heights: [CGFloat] = [0.24, 0.43, 0.64, 0.43, 0.24]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: state == .idle || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let moving = state != .idle && !reduceMotion
            let pulse = moving ? CGFloat((sin(time * (state == .speaking ? 5 : 3)) + 1) / 2) : 0
            ZStack {
                Circle()
                    .fill(Color(hex: "#C2E7F4").opacity(0.12))
                    .overlay(Circle().strokeBorder(.white.opacity(0.65), lineWidth: 1))
                    .frame(width: size * 1.42, height: size * 1.42)
                    .scaleEffect(0.94 + pulse * 0.1)
                Circle()
                    .fill(.white.opacity(0.18))
                    .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1))
                    .frame(width: size * 1.21, height: size * 1.21)
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "#F0FBFF"), Color(hex: "#BDE5F4"), Color(hex: "#79B9D4"), Color(hex: "#538FAA")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(alignment: .topLeading) {
                        Ellipse()
                            .fill(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                            .frame(width: size * 0.66, height: size * 0.30)
                            .rotationEffect(.degrees(-22))
                            .offset(x: size * 0.13, y: size * 0.08)
                    }
                    .overlay {
                        HStack(spacing: size * 0.033) {
                            ForEach(heights.indices, id: \.self) { index in
                                let waving = moving && (state == .speaking || state == .listening)
                                let scale = waving ? 0.85 + CGFloat(sin(time * (5 + Double(index) * 0.7) + Double(index))) * 0.35 : 1
                                Capsule()
                                    .fill(Color(hex: "#315E73"))
                                    .frame(width: max(3, size * 0.027), height: size * heights[index] * 0.5)
                                    .scaleEffect(x: 1, y: scale)
                            }
                        }
                    }
                    .overlay(Circle().strokeBorder(.white.opacity(0.95), lineWidth: 1))
                    .frame(width: size, height: size)
                    .scaleEffect(1 + pulse * (state == .speaking ? 0.035 : 0.018))
                    .shadow(color: Color(hex: "#467B94").opacity(0.2), radius: 20, x: 0, y: 10)
            }
            .frame(width: size * 1.42, height: size * 1.42)
        }
        .accessibilityHidden(true)
    }
}

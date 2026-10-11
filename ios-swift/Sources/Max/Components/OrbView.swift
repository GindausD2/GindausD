import SwiftUI

enum OrbState { case idle, listening, thinking, speaking }

struct OrbView: View {
    var state: OrbState = .idle
    var size: CGFloat = 128
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [Color.white, Color(hex: "#E8ECE5"), Color(hex: "#A9B5A7")], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1))
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: size * 0.28, weight: .light))
                    .foregroundStyle(Color(hex: "#596F60"))
            }
            .frame(width: size, height: size)
            .scaleEffect(expanded && !reduceMotion && state != .idle ? 1.035 : 1)
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
            .onAppear { animate() }
            .onChange(of: state) { _, _ in animate() }
            .onChange(of: reduceMotion) { _, _ in animate() }
            .accessibilityHidden(true)
    }
    private func animate() {
        expanded = false
        guard !reduceMotion, state != .idle else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { expanded = true }
    }
}

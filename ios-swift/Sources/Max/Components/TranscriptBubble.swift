import SwiftUI

struct TranscriptBubble: View {
    let message: Message
    var isStreaming: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 48) }
            if !isUser {
                MaxLogoView(width: 18)
                    .frame(width: 30, height: 38)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(message.content.isEmpty && isStreaming ? " " : message.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if isStreaming { TypingIndicator() }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.primary.opacity(0.035), lineWidth: 0.75))
            if !isUser { Spacer(minLength: 24) }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    private var bubbleColor: Color {
        if isUser { return Color(hex: colorScheme == .dark ? "#274553" : "#E0EFF5") }
        return Color(UIColor.secondarySystemGroupedBackground)
    }
}

struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 5, height: 5)
                    .opacity(animated ? 0.35 : 0.8)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(index) * 0.15), value: animated)
            }
        }
        .accessibilityLabel("Max is responding")
        .onAppear { animated = !reduceMotion }
    }
}

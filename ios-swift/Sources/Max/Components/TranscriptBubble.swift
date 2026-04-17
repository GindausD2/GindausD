import SwiftUI

// MARK: - TranscriptBubble

struct TranscriptBubble: View {
    let message: Message
    var isStreaming: Bool = false

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isUser {
                Spacer(minLength: 72)
                userBubble
            } else {
                aiBubble
                Spacer(minLength: 72)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }

    // MARK: - User Bubble — light gray, dark text

    private var userBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundStyle(Color(white: 0.12))
            .textSelection(.enabled)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Glass base
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.regularMaterial)
                    // Light gray tint
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(white: 0.88).opacity(0.70))
                    // Top specular
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.60), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.5)
                            )
                        )
                    // Hairline border
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color(white: 0.70).opacity(0.40), lineWidth: 0.5)
                }
            )
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    // MARK: - AI Bubble — white liquid glass, dark text

    private var aiBubble: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.58, green: 0.20, blue: 0.95),
                                Color(red: 0.31, green: 0.12, blue: 0.88)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                MaxLogoView(color: .white, width: 16)
            }
            .frame(width: 30, height: 30)
            .overlay(Circle().strokeBorder(.white.opacity(0.30), lineWidth: 0.75))
            .shadow(color: Color(red: 0.49, green: 0.23, blue: 0.93).opacity(0.40), radius: 6, x: 0, y: 2)
            .offset(y: 2)

            ZStack(alignment: .bottomTrailing) {
                Text(message.content.isEmpty && isStreaming ? " " : message.content)
                    .font(.body)
                    .foregroundStyle(Color(white: 0.12))
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minWidth: isStreaming && message.content.isEmpty ? 60 : 0, alignment: .leading)
                    .background(
                        ZStack {
                            // Glass base
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.regularMaterial)
                            // White tint
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.75))
                            // Specular
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.80), .clear],
                                        startPoint: .top,
                                        endPoint: UnitPoint(x: 0.5, y: 0.5)
                                    )
                                )
                            // Gradient border
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.90), Color(white: 0.75).opacity(0.25)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                        }
                    )
                    .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)

                if isStreaming {
                    TypingIndicator()
                        .padding(.trailing, 12)
                        .padding(.bottom, 10)
                }
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color(white: 0.45))
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase == i ? 1.4 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear {
            phase = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { phase = 2 }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.97, green: 0.97, blue: 1.0).ignoresSafeArea()
        ScrollView {
            VStack(spacing: 4) {
                TranscriptBubble(message: Message(role: "user", content: "Hi Max, I'm Gindaus", timestamp: Date()))
                TranscriptBubble(message: Message(role: "assistant", content: "Hello Gindaus! It's great to meet you.\n\nHow may I assist you today?", timestamp: Date()))
                TranscriptBubble(message: Message(role: "user", content: "Can you book me a flight to Paris?", timestamp: Date()))
                TranscriptBubble(message: Message(role: "assistant", content: "", timestamp: Date(), isStreaming: true), isStreaming: true)
            }
            .padding(.vertical, 16)
        }
    }
}

import SwiftUI

// MARK: - TranscriptBubble

struct TranscriptBubble: View {
    let message: Message
    var isStreaming: Bool = false

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 56)
                userBubble
            } else {
                aiBubble
                Spacer(minLength: 56)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    // MARK: - User Bubble — Violet liquid glass

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(message.content)
                .font(.body)
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        // Violet gradient base
                        BubbleShape(isUser: true)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.58, green: 0.20, blue: 0.95),
                                        Color(red: 0.31, green: 0.12, blue: 0.88)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        // Specular top highlight
                        BubbleShape(isUser: true)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.30), .clear],
                                    startPoint: .top,
                                    endPoint: UnitPoint(x: 0.5, y: 0.5)
                                )
                            )
                        // Gradient edge
                        BubbleShape(isUser: true)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.45), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.75
                            )
                    }
                )
                .shadow(
                    color: Color(red: 0.48, green: 0.16, blue: 0.88).opacity(0.50),
                    radius: 12, x: 0, y: 5
                )
                .shadow(
                    color: Color(red: 0.48, green: 0.16, blue: 0.88).opacity(0.20),
                    radius: 30, x: 0, y: 10
                )
            timestampText.padding(.trailing, 4)
        }
    }

    // MARK: - AI Bubble — Frosted glass

    private var aiBubble: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Avatar
            MaxLogoView(color: .white, width: 16)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.58, green: 0.20, blue: 0.95),
                                Color(red: 0.31, green: 0.12, blue: 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.75)
                )
                .offset(y: 2)

            VStack(alignment: .leading, spacing: 5) {
                ZStack(alignment: .bottomTrailing) {
                    Text(message.content.isEmpty && isStreaming ? " " : message.content)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(
                            minWidth: isStreaming && message.content.isEmpty ? 64 : 0,
                            alignment: .leading
                        )
                        .background(
                            ZStack {
                                // Frosted material base
                                BubbleShape(isUser: false).fill(.thinMaterial)
                                // Tint
                                BubbleShape(isUser: false).fill(Color.white.opacity(0.08))
                                // Specular
                                BubbleShape(isUser: false).fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.18), .clear],
                                        startPoint: .top,
                                        endPoint: UnitPoint(x: 0.5, y: 0.5)
                                    )
                                )
                                // Gradient edge
                                BubbleShape(isUser: false).stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.35), .white.opacity(0.04)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                            }
                        )
                        .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)

                    if isStreaming {
                        TypingIndicator()
                            .padding(.trailing, 12)
                            .padding(.bottom, 10)
                    }
                }
                timestampText.padding(.leading, 4)
            }
        }
    }

    private var timestampText: some View {
        Text(timeString(from: message.timestamp))
            .font(.caption2)
            .foregroundStyle(Color.secondary.opacity(0.7))
    }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Bubble Shape (with tail)

struct BubbleShape: Shape {
    let isUser: Bool
    let tailSize: CGFloat = 8
    let cornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, h / 2)

        if isUser {
            path.move(to: CGPoint(x: r, y: 0))
            path.addLine(to: CGPoint(x: w - r, y: 0))
            path.addArc(center: CGPoint(x: w - r, y: r), radius: r,
                        startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: w, y: h - r - tailSize))
            path.addArc(center: CGPoint(x: w - r, y: h - r - tailSize), radius: r,
                        startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: w - r + 2, y: h - tailSize))
            path.addQuadCurve(to: CGPoint(x: w + 2, y: h + 2),
                               control: CGPoint(x: w, y: h - tailSize + 2))
            path.addQuadCurve(to: CGPoint(x: w - tailSize - 2, y: h),
                               control: CGPoint(x: w - 2, y: h))
            path.addLine(to: CGPoint(x: r, y: h))
            path.addArc(center: CGPoint(x: r, y: h - r), radius: r,
                        startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: 0, y: r))
            path.addArc(center: CGPoint(x: r, y: r), radius: r,
                        startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            path.move(to: CGPoint(x: r, y: 0))
            path.addLine(to: CGPoint(x: w - r, y: 0))
            path.addArc(center: CGPoint(x: w - r, y: r), radius: r,
                        startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: w, y: h - r))
            path.addArc(center: CGPoint(x: w - r, y: h - r), radius: r,
                        startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: tailSize + 2, y: h))
            path.addQuadCurve(to: CGPoint(x: -2, y: h + 2),
                               control: CGPoint(x: 2, y: h))
            path.addQuadCurve(to: CGPoint(x: r - 2, y: h - tailSize),
                               control: CGPoint(x: 0, y: h - tailSize + 2))
            path.addLine(to: CGPoint(x: 0, y: r + tailSize))
            path.addArc(center: CGPoint(x: r, y: r), radius: r,
                        startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.55))
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
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.01, blue: 0.06),
                Color(red: 0.06, green: 0.03, blue: 0.13)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 4) {
                TranscriptBubble(message: Message(
                    role: "user",
                    content: "Hey Max, what's on my calendar today?",
                    timestamp: Date()
                ))
                TranscriptBubble(message: Message(
                    role: "assistant",
                    content: "I don't have calendar access right now, but I can set a reminder for you! Would you like me to do that?",
                    timestamp: Date()
                ))
                TranscriptBubble(message: Message(
                    role: "user",
                    content: "Yes please!",
                    timestamp: Date()
                ))
                TranscriptBubble(
                    message: Message(role: "assistant", content: "", timestamp: Date(), isStreaming: true),
                    isStreaming: true
                )
            }
            .padding(.vertical, 16)
        }
    }
    .environment(\.colorScheme, .dark)
}

import SwiftUI

// MARK: - TranscriptBubble

struct TranscriptBubble: View {
    let message: Message
    var isStreaming: Bool = false

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 48)
                userBubble
            } else {
                aiBubble
                Spacer(minLength: 48)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.body)
                .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.12))
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.91, green: 0.91, blue: 0.914))
                )
                .clipShape(
                    BubbleShape(isUser: true)
                )
            timestampText
                .padding(.trailing, 4)
        }
    }

    // MARK: - AI Bubble

    private var aiBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // AI avatar dot
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.2, blue: 0.9),
                            Color(red: 0.49, green: 0.23, blue: 0.93)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 26, height: 26)
                .overlay(
                    Text("M")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                )
                .offset(y: 2)

            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    Text(message.content.isEmpty && isStreaming ? " " : message.content)
                        .font(.body)
                        .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.12))
                        .textSelection(.enabled)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .frame(minWidth: isStreaming && message.content.isEmpty ? 60 : 0, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white)
                                .shadow(
                                    color: Color.black.opacity(0.08),
                                    radius: 6,
                                    x: 0,
                                    y: 2
                                )
                        )
                        .clipShape(
                            BubbleShape(isUser: false)
                        )

                    if isStreaming {
                        TypingIndicator()
                            .padding(.trailing, 12)
                            .padding(.bottom, 10)
                    }
                }

                timestampText
                    .padding(.leading, 4)
            }
        }
    }

    private var timestampText: some View {
        Text(timeString(from: message.timestamp))
            .font(.caption2)
            .foregroundStyle(Color.secondary.opacity(0.65))
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Bubble Shape (tail)

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
            // User bubble: tail at bottom-right
            path.move(to: CGPoint(x: r, y: 0))
            path.addLine(to: CGPoint(x: w - r, y: 0))
            path.addArc(center: CGPoint(x: w - r, y: r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: w, y: h - r - tailSize))
            path.addArc(center: CGPoint(x: w - r, y: h - r - tailSize), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: w - r + 2, y: h - tailSize))
            path.addQuadCurve(to: CGPoint(x: w + 2, y: h + 2), control: CGPoint(x: w, y: h - tailSize + 2))
            path.addQuadCurve(to: CGPoint(x: w - tailSize - 2, y: h), control: CGPoint(x: w - 2, y: h))
            path.addLine(to: CGPoint(x: r, y: h))
            path.addArc(center: CGPoint(x: r, y: h - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: 0, y: r))
            path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            // AI bubble: tail at bottom-left
            path.move(to: CGPoint(x: r, y: 0))
            path.addLine(to: CGPoint(x: w - r, y: 0))
            path.addArc(center: CGPoint(x: w - r, y: r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: w, y: h - r))
            path.addArc(center: CGPoint(x: w - r, y: h - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: tailSize + 2, y: h))
            path.addQuadCurve(to: CGPoint(x: -2, y: h + 2), control: CGPoint(x: 2, y: h))
            path.addQuadCurve(to: CGPoint(x: r - 2, y: h - tailSize), control: CGPoint(x: 0, y: h - tailSize + 2))
            path.addLine(to: CGPoint(x: 0, y: r + tailSize))
            path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
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
                    .fill(Color.secondary.opacity(0.5))
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                phase = 2
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 8) {
            TranscriptBubble(message: Message(
                role: "user",
                content: "Hey Max! What's the weather like today?",
                timestamp: Date()
            ))

            TranscriptBubble(message: Message(
                role: "assistant",
                content: "I don't have access to live weather data, but I can check the date and time for you! Would you like me to set a reminder to check the forecast?",
                timestamp: Date()
            ))

            TranscriptBubble(message: Message(
                role: "user",
                content: "Sure!",
                timestamp: Date()
            ))

            TranscriptBubble(message: Message(
                role: "assistant",
                content: "",
                timestamp: Date(),
                isStreaming: true
            ), isStreaming: true)
        }
        .padding(.vertical, 12)
    }
    .background(Color(.systemBackground))
}

import SwiftUI

/// The microphone captures a draft; the user decides when to send it.
struct VoiceToTextPanel: View {
    let transcript: String
    let isPreparing: Bool
    let isFinishing: Bool
    let onCancel: () -> Void
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ink = Color(hex: "#315E73")

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.title3)
                    .foregroundStyle(ink)
                    .symbolEffect(.variableColor, isActive: !reduceMotion && !isPreparing && !isFinishing)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isPreparing ? "Getting ready…" : isFinishing ? "Finishing…" : "Listening")
                        .font(.headline)
                    Text("Voice to text")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isPreparing || isFinishing { ProgressView().tint(ink) }
            }

            ScrollView {
                Text(transcript.isEmpty ? "Speak naturally. Your words appear here." : transcript)
                    .font(.title3)
                    .foregroundStyle(transcript.isEmpty ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 60, maxHeight: 116)
            .accessibilityLabel("Live transcription")

            Text("Review and edit before sending.")
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .font(.body.weight(.medium))
                    .frame(minWidth: 70, minHeight: 44)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 22)
                        .frame(minHeight: 48)
                        .foregroundStyle(ink)
                        .background(Color(hex: "#C7E7F1"), in: Capsule())
                }
                .disabled(isPreparing || isFinishing)
                .accessibilityHint("Put the transcription into your message draft without sending it")
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .glassCard(cornerRadius: 32, depth: .regular)
    }
}

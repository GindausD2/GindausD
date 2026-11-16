import SwiftUI

struct AIProcessingConsent {
    static let version = "1"
    static let header = "X-Max-OpenAI-Consent"
}

struct AIPrivacyView: View {
    let scope: String
    @Environment(\.dismiss) private var dismiss
    @State private var approved = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Cloud processing") {
                    Text("To answer you, Max sends your messages and relevant saved context through Max’s server to OpenAI. Voice features can also send recordings and vocabulary hints for transcription, or text for spoken replies.")
                    Link("OpenAI API data controls", destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!)
                }
                Section {
                    Text(approved ? "Cloud AI is allowed on this device for this account." : "You can still use saved notes and reminders without enabling cloud AI.")
                    if approved {
                        Button("Withdraw permission", role: .destructive) { choose(false) }
                    } else {
                        Button("Allow cloud AI") { choose(true) }
                        Button("Not now", role: .cancel) { dismiss() }
                    }
                }
            }
            .navigationTitle("AI privacy")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onAppear { approved = StorageService.shared.allowsCloudAI(scope: scope) }
        }
    }

    private func choose(_ allow: Bool) {
        guard StorageService.shared.setCloudAIAllowed(allow, scope: scope) else {
            dismiss()
            return
        }
        if !allow {
            VoiceService.shared.stopRecording()
            VoiceService.shared.stopSpeaking()
            VoiceService.shared.clearRecentCloudSpeech()
        }
        dismiss()
    }
}

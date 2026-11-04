import ActivityKit
import AppIntents
import SwiftUI
import UIKit

/// Shortcuts setup and a clearly labelled preview of Max's Live Activity controls.
struct IslandOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            CompanionCanvas()
            VStack(spacing: 0) {
                CompanionSheetHeader(title: "Dynamic Island", onClose: { dismiss() })
                ScrollView {
                    VStack(spacing: 26) {
                        VStack(spacing: 12) {
                            Text("A little closer to your day.").font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                            Text("Start Max from Shortcuts, then keep its voice and daily briefing controls within reach.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        VStack(spacing: 14) {
                            HStack(spacing: 10) {
                                MaxLogoView(width: 36)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Max").font(.subheadline.weight(.semibold))
                                    Text("Ready when you are").font(.caption).foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                                Image(systemName: "waveform").foregroundStyle(Color(hex: "#BCE8F5"))
                            }
                            .padding(18).foregroundStyle(.white)
                            .background(Color(hex: "#182126"), in: Capsule())
                            Text("Preview").font(.caption).foregroundStyle(.secondary)
                        }
                        shortcutSetup
                        VStack(spacing: 0) {
                            islandRow("Talk", icon: "mic", detail: "Return to Max for a voice conversation.")
                            Divider().padding(.leading, 54)
                            islandRow("Briefing", icon: "sun.horizon", detail: "Open your morning summary.")
                            Divider().padding(.leading, 54)
                            islandRow("Plan", icon: "calendar", detail: "Start planning your day with Max.")
                        }.glassCard(cornerRadius: 28)
                        VStack(spacing: 14) {
                            Label(activitiesEnabled ? "Live Activities are available" : "Live Activities are turned off", systemImage: activitiesEnabled ? "checkmark.circle" : "info.circle")
                                .font(.subheadline.weight(.medium))
                            Button("iPhone settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }.buttonStyle(GlassPillButtonStyle())
                            Text("A Live Activity is temporary; iOS controls when it ends. Run the shortcut again to start a new session. iPhones without Dynamic Island use the Lock Screen. Talking opens Max and needs microphone permission.")
                                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                    }.padding(.horizontal, 22).padding(.vertical, 24)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled } }
        .presentationCornerRadius(34).presentationDragIndicator(.hidden)
    }

    private var shortcutSetup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Connect with Shortcuts").font(.headline)
            setupStep("1", title: "Open Max's shortcuts", detail: "Tap the button below to find Max in the Shortcuts app.")
            setupStep("2", title: "Run Start Max Island", detail: "Max opens. Finish login or your demo if asked, and allow Live Activities in iPhone settings.")
            setupStep("3", title: "Keep Max within reach", detail: "Return to your Home Screen. Touch and hold Max in Dynamic Island, then tap Talk, Briefing or Plan. On other iPhones, use the Lock Screen card.")
            ShortcutsLink()
                .shortcutsLinkStyle(.automaticOutline)
                .frame(maxWidth: .infinity)
            Text("For direct voice input, choose Activate Max. You can also assign either shortcut to an Action Button on supported iPhones.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 28)
    }

    private func setupStep(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.caption.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(Color(hex: "#BCE8F5").opacity(0.3), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func islandRow(_ title: String, icon: String, detail: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title3).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(18)
    }
}

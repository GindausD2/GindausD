import ActivityKit
import SwiftUI
import UIKit

/// A preview of Max's existing Live Activity controls, without simulated live data.
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
                            Text("Max's Live Activity keeps your conversation and reminder cards within reach.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        VStack(spacing: 14) {
                            HStack(spacing: 10) {
                                OrbView(size: 28)
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
                            Text("iOS controls the activity's lifetime. On iPhones without Dynamic Island, Max uses the Lock Screen.")
                                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                    }.padding(.horizontal, 22).padding(.vertical, 24)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled } }
        .presentationCornerRadius(34).presentationDragIndicator(.hidden)
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

// MaxLiveActivity Widget Extension
//
// ── Xcode Setup Required ──────────────────────────────────────────────────────
// 1. File → New → Target → Widget Extension
//    · Name: MaxLiveActivity
//    · Uncheck "Include Configuration App Intent"
//    · Ensure "Include Live Activity" is checked
// 2. Add MaxActivityAttributes.swift to this target's membership
//    (or create a shared framework that both targets link against)
// 3. In the main app's Info.plist add:
//    NSSupportsLiveActivities → YES
// 4. In the widget extension's Info.plist add:
//    NSExtensionAttributes → NSWidgetWantsLocation → NO
// ─────────────────────────────────────────────────────────────────────────────

import ActivityKit
import SwiftUI
import WidgetKit

// Re-declare attributes here (or import from shared module)
// This mirrors MaxActivityAttributes.swift in the main target.
// When using a shared framework, replace this with an import.
typealias MaxAttr = MaxActivityAttributes

// MARK: - Widget Bundle

@main
struct MaxLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        MaxLiveActivityWidget()
    }
}

// MARK: - Widget

struct MaxLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MaxAttr.self) { context in
            // Lock Screen / StandBy banner
            MaxLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded (long-press) ──────────────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    MaxExpandedLeading()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MaxExpandedTrailing(phase: context.state.phase)
                }
                DynamicIslandExpandedRegion(.center) {
                    MaxExpandedCenter(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.state.snippet.isEmpty {
                        MaxExpandedSnippet(snippet: context.state.snippet)
                    }
                }
            } compactLeading: {
                // ── Compact leading: Max logo ──────────────────────────────
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(Color(red: 0.58, green: 0.20, blue: 0.95))
                    .font(.system(size: 13, weight: .semibold))
            } compactTrailing: {
                // ── Compact trailing: phase icon ──────────────────────────
                PhaseIcon(phase: context.state.phase, size: 13)
            } minimal: {
                // ── Minimal (pill only shows one icon) ─────────────────────
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(Color(red: 0.58, green: 0.20, blue: 0.95))
                    .font(.system(size: 12, weight: .semibold))
            }
            .keylineTint(Color(red: 0.49, green: 0.23, blue: 0.93))
        }
    }
}

// MARK: - Lock Screen / StandBy Banner

private struct MaxLockScreenView: View {
    let context: ActivityViewContext<MaxAttr>

    var body: some View {
        HStack(spacing: 14) {
            // Avatar / orb
            ZStack {
                Circle()
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
                    .frame(width: 44, height: 44)
                PhaseIcon(phase: context.state.phase, size: 18)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Max")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("·")
                        .foregroundStyle(.white.opacity(0.5))
                    Text(context.state.phase.label)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }

                if !context.state.snippet.isEmpty {
                    Text(context.state.snippet)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.60))
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.03, blue: 0.13),
                    Color(red: 0.16, green: 0.06, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Expanded Regions

private struct MaxExpandedLeading: View {
    var body: some View {
        ZStack {
            Circle()
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
                .frame(width: 36, height: 36)
            Image(systemName: "moon.stars.fill")
                .foregroundStyle(.white)
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.leading, 4)
    }
}

private struct MaxExpandedTrailing: View {
    let phase: MaxAttr.ContentState.Phase

    var body: some View {
        PhaseIcon(phase: phase, size: 16)
            .foregroundStyle(phaseColor(phase))
            .padding(.trailing, 4)
    }
}

private struct MaxExpandedCenter: View {
    let state: MaxAttr.ContentState

    var body: some View {
        VStack(spacing: 1) {
            Text("Max")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(state.phase.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.65))
        }
    }
}

private struct MaxExpandedSnippet: View {
    let snippet: String

    var body: some View {
        Text(snippet)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.75))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
}

// MARK: - Shared helpers

private struct PhaseIcon: View {
    let phase: MaxAttr.ContentState.Phase
    let size: CGFloat

    var body: some View {
        Image(systemName: phase.symbolName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(phaseColor(phase))
            .symbolEffect(.variableColor.iterative, isActive: phase != .idle)
    }
}

private func phaseColor(_ phase: MaxAttr.ContentState.Phase) -> Color {
    switch phase {
    case .idle:      return Color(red: 0.65, green: 0.55, blue: 0.98)
    case .listening: return Color(red: 0.94, green: 0.27, blue: 0.27)
    case .thinking:  return Color(red: 0.49, green: 0.29, blue: 0.93)
    case .speaking:  return Color(red: 0.23, green: 0.51, blue: 0.96)
    }
}

// MARK: - Preview

#Preview("Dynamic Island — Listening", as: .dynamicIsland(.compact), using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .listening, snippet: "")
    MaxAttr.ContentState(phase: .thinking, snippet: "What's the weather like today?")
    MaxAttr.ContentState(phase: .speaking, snippet: "It's sunny and 72°F outside right now.")
}

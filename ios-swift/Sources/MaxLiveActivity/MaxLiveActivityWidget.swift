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

typealias MaxAttr = MaxActivityAttributes

// MARK: - Brand colors

private let violet      = Color(red: 0.49, green: 0.23, blue: 0.93)
private let violetDeep  = Color(red: 0.31, green: 0.12, blue: 0.88)
private let violetLight = Color(red: 0.65, green: 0.55, blue: 0.98)
private let red         = Color(red: 0.94, green: 0.27, blue: 0.27)
private let blue        = Color(red: 0.23, green: 0.51, blue: 0.96)
private let cardBg      = Color(red: 0.06, green: 0.04, blue: 0.10)

// MARK: - Widget Bundle

@main
struct MaxLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        MaxLiveActivityWidget()
    }
}

// MARK: - Widget Configuration

struct MaxLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MaxAttr.self) { context in
            MaxLockScreenCard(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded (long-press on the pill) ─────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    MaxLogoView(color: .white, width: 56)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PhaseIconView(phase: context.state.phase, size: 18)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .center, spacing: 0) {
                        Text("Max")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        Text(context.state.phase.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(phaseAccent(context.state.phase))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.state.snippet.isEmpty {
                        Text(context.state.snippet)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                    }
                }
            } compactLeading: {
                // ── Compact: triple moon logo ─────────────────────────────────
                MaxLogoView(color: .white, width: 32)
                    .padding(.leading, 2)
            } compactTrailing: {
                // ── Compact: animated phase icon ──────────────────────────────
                PhaseIconView(phase: context.state.phase, size: 13)
            } minimal: {
                // ── Minimal: just the center ring of the logo at tiny size ────
                MaxLogoView(color: .white, width: 24)
            }
            .keylineTint(violet)
        }
    }
}

// MARK: - Lock Screen / StandBy Card
//
// Layout mirrors the reference screenshot:
//   [avatar]  Max                          [time elapsed]
//   [phase label — accent color]            Claude
//
//   Bold headline transcript text
//

private struct MaxLockScreenCard: View {
    let context: ActivityViewContext<MaxAttr>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Row 1: triple moon logo + app name + source ───────────────────
            HStack(spacing: 10) {
                // Triple moon logo — same width as the "StarCy" avatar in the reference
                MaxLogoView(color: .white, width: 52)

                Text("Max")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Text("Claude")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            .padding(.bottom, 10)

            // ── Row 2: phase label (accent) + source tag ──────────────────────
            HStack(alignment: .center, spacing: 0) {
                // Phase label — violet / red / blue depending on state
                Text(context.state.phase.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(phaseAccent(context.state.phase))

                Spacer()

                // "AI Assistant" source tag — mirrors "The Verge" in screenshot
                Text("AI Assistant")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.40))
            }
            .padding(.bottom, 8)

            // ── Body: bold headline content ───────────────────────────────────
            if context.state.snippet.isEmpty {
                // Placeholder when no transcript yet
                Text(context.state.phase.emptyLabel)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
            } else {
                Text(context.state.snippet)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(cardBg)
        .activityBackgroundTint(cardBg)
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Max Logo View (triple moon — mirrored from MaxLogoView in main target)
//
// Widget extensions cannot import views from the main app target,
// so the canvas drawing is duplicated here.

private struct MaxLogoView: View {
    var color: Color = .white
    var width: CGFloat

    private var height: CGFloat { width * 44 / 100 }

    var body: some View {
        Canvas(opaque: false, colorMode: .linear) { context, size in
            let u = size.width / 100.0

            func ellipse(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(
                    x: (cx - r) * u, y: (cy - r) * u,
                    width: 2 * r * u, height: 2 * r * u
                ))
            }

            // Left crescent
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 15, cy: 22, r: 21), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 24, cy: 22, r: 16), with: .color(.black))
            }
            // Center ring
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 50, cy: 22, r: 14), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 50, cy: 22, r:  9), with: .color(.black))
            }
            // Right crescent
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 85, cy: 22, r: 21), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 76, cy: 22, r: 16), with: .color(.black))
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Avatar View (violet pill containing the triple moon logo)

private struct MaxAvatarView: View {
    let size: CGFloat

    // Logo width is ~2.4× the avatar height so the three moons fit legibly
    private var logoWidth: CGFloat { size * 2.2 }

    var body: some View {
        MaxLogoView(color: .white, width: logoWidth)
    }
}

// MARK: - Phase Icon (animated SF Symbol)

private struct PhaseIconView: View {
    let phase: MaxAttr.ContentState.Phase
    let size: CGFloat

    var body: some View {
        Image(systemName: phase.symbolName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(phaseAccent(phase))
            .symbolEffect(.variableColor.iterative, isActive: phase != .idle)
    }
}

// MARK: - Helpers

private func phaseAccent(_ phase: MaxAttr.ContentState.Phase) -> Color {
    switch phase {
    case .idle:      return violetLight
    case .listening: return red
    case .thinking:  return violet
    case .speaking:  return blue
    }
}

// MARK: - Extend MaxActivityAttributes.ContentState.Phase

extension MaxActivityAttributes.ContentState.Phase {
    /// Text shown in the card body when snippet is empty
    var emptyLabel: String {
        switch self {
        case .idle:      return "Ready to assist you."
        case .listening: return "Listening to you…"
        case .thinking:  return "Thinking through your request…"
        case .speaking:  return "Preparing a response…"
        }
    }
}

// MARK: - Previews

#Preview("Lock Screen — Listening", as: .content, using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .listening, snippet: "")
}

#Preview("Lock Screen — Thinking", as: .content, using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .thinking, snippet: "What's the weather like today?")
}

#Preview("Lock Screen — Speaking", as: .content, using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .speaking, snippet: "It's currently sunny and 72°F outside right now. Perfect day for a walk!")
}

#Preview("Dynamic Island — Compact", as: .dynamicIsland(.compact), using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .listening, snippet: "")
    MaxAttr.ContentState(phase: .thinking, snippet: "What's the weather like today?")
    MaxAttr.ContentState(phase: .speaking, snippet: "It's sunny and 72°F outside.")
}

#Preview("Dynamic Island — Expanded", as: .dynamicIsland(.expanded), using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .listening, snippet: "")
    MaxAttr.ContentState(phase: .thinking, snippet: "What's on my calendar today?")
    MaxAttr.ContentState(phase: .speaking, snippet: "You have a meeting at 3pm and dinner at 7.")
}

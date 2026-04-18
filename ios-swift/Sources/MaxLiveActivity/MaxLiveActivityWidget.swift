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
                    if context.state.toolCard == nil {
                        PhaseIconView(phase: context.state.phase, size: 18)
                            .padding(.trailing, 6)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .center, spacing: 0) {
                        Text("Max")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        Text(context.state.toolCard != nil ? "Done" : context.state.phase.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(context.state.toolCard != nil ? violetLight : phaseAccent(context.state.phase))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let card = context.state.toolCard {
                        ToolCardView(card: card)
                            .padding(.bottom, 10)
                    } else if !context.state.snippet.isEmpty {
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
                // ── Compact: tool card icon when active, else phase icon ───────
                if let card = context.state.toolCard {
                    Image(systemName: card.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(toolCardAccent(card.kind))
                } else {
                    PhaseIconView(phase: context.state.phase, size: 13)
                }
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
//   Bold headline transcript text OR tool action card
//

private struct MaxLockScreenCard: View {
    let context: ActivityViewContext<MaxAttr>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Row 1: triple moon logo + app name + source ───────────────────
            HStack(spacing: 10) {
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
                Text(context.state.toolCard != nil ? "Action Complete" : context.state.phase.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(context.state.toolCard != nil ? violetLight : phaseAccent(context.state.phase))

                Spacer()

                Text("AI Assistant")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.40))
            }
            .padding(.bottom, 8)

            // ── Body: tool card OR bold headline content ──────────────────────
            if let card = context.state.toolCard {
                ToolCardView(card: card)
            } else if context.state.snippet.isEmpty {
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

// MARK: - Tool Card View

private struct ToolCardView: View {
    let card: MaxAttr.ContentState.ToolCard

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: card.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(toolCardAccent(card.kind))
                .frame(width: 32, height: 32)
                .background(toolCardAccent(card.kind).opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(card.line1)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(card.line2)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Max Logo View (triple moon — mirrored from MaxLogoView in main target)
//
// Widget extensions cannot import views from the main app target,
// so the canvas drawing is duplicated here.

private struct MaxLogoView: View {
    var color: Color = .white
    var width: CGFloat

    private var height: CGFloat { width * 50 / 100 }

    var body: some View {
        Canvas(opaque: false, colorMode: .linear) { context, size in
            let u = size.width / 100.0

            func ellipse(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(
                    x: (cx - r) * u, y: (cy - r) * u,
                    width: 2 * r * u, height: 2 * r * u
                ))
            }

            // Left crescent (opens right, tips kiss center ring)
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 18, cy: 25, r: 24), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 29, cy: 25, r: 19), with: .color(.black))
            }
            // Center ring
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 50, cy: 25, r: 17), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 50, cy: 25, r: 10), with: .color(.black))
            }
            // Right crescent (opens left, tips kiss center ring)
            context.drawLayer { ctx in
                ctx.fill(ellipse(cx: 82, cy: 25, r: 24), with: .color(color))
                ctx.blendMode = .destinationOut
                ctx.fill(ellipse(cx: 71, cy: 25, r: 19), with: .color(.black))
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Avatar View (violet pill containing the triple moon logo)

private struct MaxAvatarView: View {
    let size: CGFloat

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

private func toolCardAccent(_ kind: MaxAttr.ContentState.ToolCard.Kind) -> Color {
    switch kind {
    case .uber:       return Color(red: 0.0, green: 0.72, blue: 0.45)   // Uber green
    case .flight:     return Color(red: 0.23, green: 0.51, blue: 0.96)  // Blue
    case .email:      return Color(red: 0.94, green: 0.55, blue: 0.12)  // Orange
    case .call:       return Color(red: 0.20, green: 0.78, blue: 0.35)  // Green
    case .calendar:   return Color(red: 0.94, green: 0.27, blue: 0.27)  // Red
    case .directions: return Color(red: 0.23, green: 0.51, blue: 0.96)  // Blue
    case .news:       return violetLight
    case .reminder:   return Color(red: 0.94, green: 0.55, blue: 0.12)  // Orange
    }
}

// MARK: - Extend MaxActivityAttributes.ContentState.Phase

extension MaxActivityAttributes.ContentState.Phase {
    /// Text shown in the card body when snippet is empty
    var emptyLabel: String {
        switch self {
        case .idle:      return "Tap to talk with Max."
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

#Preview("Lock Screen — Uber Card", as: .content, using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .idle, snippet: "", toolCard: .init(kind: .uber, line1: "Heathrow → Paddington", line2: "Opening Uber…", iconName: "car.fill"))
}

#Preview("Lock Screen — Flight Card", as: .content, using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .idle, snippet: "", toolCard: .init(kind: .flight, line1: "JFK → LAX", line2: "May 10 · 2 pax", iconName: "airplane"))
}

#Preview("Lock Screen — News Card", as: .content, using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .idle, snippet: "", toolCard: .init(kind: .news, line1: "UK economy grows faster than expected", line2: "BBC News", iconName: "newspaper.fill"))
}

#Preview("Lock Screen — Directions Card", as: .content, using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .idle, snippet: "", toolCard: .init(kind: .directions, line1: "nearest café", line2: "Opening Maps…", iconName: "map.fill"))
}

#Preview("Dynamic Island — Compact", as: .dynamicIsland(.compact), using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .listening, snippet: "")
    MaxAttr.ContentState(phase: .thinking, snippet: "What's the weather like today?")
    MaxAttr.ContentState(phase: .idle, snippet: "", toolCard: .init(kind: .uber, line1: "Heathrow → Paddington", line2: "Opening Uber…", iconName: "car.fill"))
}

#Preview("Dynamic Island — Expanded", as: .dynamicIsland(.expanded), using: MaxAttr(sessionLabel: "Max AI")) {
    MaxLiveActivityWidget()
} contentStates: {
    MaxAttr.ContentState(phase: .listening, snippet: "")
    MaxAttr.ContentState(phase: .thinking, snippet: "What's on my calendar today?")
    MaxAttr.ContentState(phase: .idle, snippet: "", toolCard: .init(kind: .calendar, line1: "Dentist Appointment", line2: "Apr 20 at 3:00 PM", iconName: "calendar.badge.plus"))
}

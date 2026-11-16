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
import UIKit

typealias MaxAttr = MaxActivityAttributes

private let glacier = Color(red: 0.57, green: 0.81, blue: 0.93)

@main
struct MaxLiveActivityBundle: WidgetBundle {
    var body: some Widget { MaxLiveActivityWidget() }
}

struct MaxLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MaxAttr.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                IslandHeader(state: context.state)
                IslandDetails(state: context.state, showCameraPreview: false)
            }
            .padding(14)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
            .widgetURL(URL(string: context.state.camera == nil ? "maxapp://listen" : "maxapp://camera"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandHeader(state: context.state)
                        .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    IslandDetails(state: context.state)
                        .padding(.horizontal, 6)
                }
            } compactLeading: {
                IslandOrb(size: 18)
            } compactTrailing: {
                if context.state.camera != nil || context.state.phase != .idle || context.state.toolCard != nil || context.state.emailAlert != nil {
                    Image(systemName: context.state.statusSymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(glacier)
                        .accessibilityLabel(Text(context.state.statusLabel))
                }
            } minimal: {
                IslandOrb(size: 17)
                    .accessibilityLabel(Text("Max, " + context.state.statusLabel))
            }
            .keylineTint(glacier)
            .widgetURL(URL(string: context.state.camera == nil ? "maxapp://listen" : "maxapp://camera"))
        }
        .supplementalActivityFamilies([.small])
    }
}

private struct IslandOrb: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [.white, glacier, Color(red: 0.10, green: 0.29, blue: 0.41)],
                                 center: .topLeading, startRadius: 0, endRadius: size))
            .overlay(alignment: .bottomTrailing) {
                Circle().fill(.white.opacity(0.12)).frame(width: size * 0.47, height: size * 0.47)
            }
            .overlay { Circle().strokeBorder(.white.opacity(0.38), lineWidth: 0.5) }
            .frame(width: size, height: size)
    }
}

private struct IslandHeader: View {
    let state: MaxAttr.ContentState

    var body: some View {
        HStack(spacing: 9) {
            IslandOrb(size: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Max").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                HStack(spacing: 4) {
                    Circle().fill(state.phase == .listening ? .red : glacier)
                        .frame(width: 5, height: 5).accessibilityHidden(true)
                    Text(state.statusLabel).font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.76))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct IslandDetails: View {
    let state: MaxAttr.ContentState
    var showCameraPreview = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let camera = state.camera {
                if showCameraPreview { cameraDetails(camera) }
            } else if let card = state.toolCard {
                if let heading = card.taskHeading {
                    Text(heading).font(.headline).lineLimit(1)
                }
                detail(icon: card.iconName, title: card.line1, subtitle: card.line2)
                if card.kind == .reminder, card.reminderStage != nil {
                    reminderProgress(stage: card.reminderStage)
                }
            } else if let alert = state.emailAlert {
                detail(icon: "envelope.fill", title: "\(alert.count) unread",
                       subtitle: "Open Max to review")
            } else if !state.snippet.isEmpty {
                Text(state.snippet)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .privacySensitive()
            }
            if state.phase == .idle && state.camera == nil {
                HStack(spacing: 14) {
                    Link(destination: URL(string: "maxapp://listen")!) { Label("Talk", systemImage: "mic") }
                    Link(destination: URL(string: "maxapp://briefing")!) { Label("Briefing", systemImage: "sun.horizon") }
                    Link(destination: URL(string: "maxapp://quick")!) { Label("Plan", systemImage: "clock") }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(glacier)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
    }

    private func cameraDetails(_ camera: MaxAttr.ContentState.CameraCard) -> some View {
        HStack(alignment: .center, spacing: 9) {
            if let url = camera.thumbnailURL, let photo = UIImage(contentsOfFile: url.path) {
                Image(uiImage: photo).resizable().scaledToFill()
                    .frame(width: 43, height: 43)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
            }
            if let result = camera.result {
                Text(result)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(4)
            } else {
                Text(camera.stage == .captured ? "Open Max to identify" : camera.stage.label)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
        }
        .privacySensitive()
    }

    private func detail(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(glacier)
                .frame(width: 29, height: 29)
                .background(glacier.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption2).foregroundStyle(.white.opacity(0.72)).lineLimit(1)
                }
            }
            .privacySensitive()
        }
        .accessibilityElement(children: .combine)
    }

    private func reminderProgress(stage: MaxAttr.ContentState.ToolCard.ReminderStage?) -> some View {
        let set = stage == .set
        return HStack(spacing: 5) {
            progressSegment("Setting", completed: true)
            progressSegment("Set", completed: set)
        }
        .accessibilityHidden(true)
    }

    private func progressSegment(_ label: String, completed: Bool) -> some View {
        VStack(spacing: 3) {
            Capsule().fill(completed ? glacier : .white.opacity(0.24)).frame(height: 3)
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(completed ? glacier : .white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
    }
}

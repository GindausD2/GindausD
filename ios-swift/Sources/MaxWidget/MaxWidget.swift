import SwiftUI
import WidgetKit

// ── Xcode setup ────────────────────────────────────────────────────────────────
//
// 1. File → New → Target → Widget Extension, name it "MaxWidget"
//    • Uncheck "Include Live Activity" and "Include Configuration App Intent"
//    • Point its source folder at Sources/MaxWidget/
//
// 2. Add an App Group capability to BOTH the main app and this widget target:
//    • Identifier: group.com.gindausd.max
//
// 3. Register the URL scheme in the main app target → Info → URL Types:
//    • Identifier: com.gindausd.max
//    • URL Schemes: maxapp
//    (This lets the widget deep-link into listening mode.)
//
// 4. In MaxApp.swift, MaxApp.body already contains the .onOpenURL handler
//    that fires when the user taps the "Tap to listen" widget.
//
// ──────────────────────────────────────────────────────────────────────────────

// MARK: - Shared defaults keys (must match HomeViewModel)

enum WidgetDefaults {
    static let suiteName  = "group.com.gindausd.max"
    static let lastMsg    = "max:widget_last_message"
    static let lastMsgAt  = "max:widget_last_message_time"
}

// MARK: - Timeline entry

struct MaxWidgetEntry: TimelineEntry {
    let date: Date
    let lastMessage: String
    let lastMessageAt: Date?
}

// MARK: - Timeline provider

struct MaxWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MaxWidgetEntry {
        MaxWidgetEntry(date: Date(), lastMessage: "Ready to help you.", lastMessageAt: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (MaxWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MaxWidgetEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> MaxWidgetEntry {
        let def = UserDefaults(suiteName: WidgetDefaults.suiteName)
        let msg  = def?.string(forKey: WidgetDefaults.lastMsg) ?? "Ready to help you."
        let time = def?.object(forKey: WidgetDefaults.lastMsgAt) as? Date
        return MaxWidgetEntry(date: Date(), lastMessage: msg, lastMessageAt: time)
    }
}

// MARK: - Static orb (no animation — widgets are snapshots)

private struct WidgetOrb: View {
    let size: CGFloat

    private let c0 = Color(red: 1.00, green: 0.55, blue: 0.05)
    private let c1 = Color(red: 0.95, green: 0.35, blue: 0.00)
    private let c2 = Color(red: 1.00, green: 0.70, blue: 0.10)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [c0.opacity(0.38), Color.clear],
                    center: .center,
                    startRadius: size * 0.3,
                    endRadius: size * 0.65
                ))
                .frame(width: size * 1.4, height: size * 1.4)

            Circle()
                .fill(RadialGradient(
                    colors: [c0, c1, c2.opacity(0.85)],
                    center: .init(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: size * 0.55
                ))
                .frame(width: size, height: size)
                .overlay(
                    Ellipse()
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.clear],
                            startPoint: .init(x: 0.25, y: 0.15),
                            endPoint: .init(x: 0.6, y: 0.55)
                        ))
                        .frame(width: size * 0.42, height: size * 0.28)
                        .offset(x: -size * 0.12, y: -size * 0.18)
                )
                .shadow(color: c0.opacity(0.65), radius: size * 0.22, x: 0, y: size * 0.08)
                .shadow(color: c1.opacity(0.40), radius: size * 0.40, x: 0, y: 0)
        }
    }
}

// MARK: - Small widget (2 × 2)

private struct SmallWidgetView: View {
    let entry: MaxWidgetEntry

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.04, blue: 0.02)

            VStack(spacing: 6) {
                WidgetOrb(size: 56)

                Text("Max")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("Tap to talk")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.05).opacity(0.85))
            }
        }
        .widgetURL(URL(string: "maxapp://listen"))
    }
}

// MARK: - Medium widget (4 × 2)

private struct MediumWidgetView: View {
    let entry: MaxWidgetEntry

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.04, blue: 0.02)

            HStack(spacing: 0) {
                // Left: orb + label
                VStack(spacing: 5) {
                    WidgetOrb(size: 52)
                    Text("Max")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Text("AI Assistant")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .frame(width: 90)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
                    .padding(.vertical, 12)

                // Right: last message
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.lastMessage)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    if let t = entry.lastMessageAt {
                        Text(relativeTime(t))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.05).opacity(0.7))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
        }
        .widgetURL(URL(string: "maxapp://listen"))
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60    { return "just now" }
        if diff < 3600  { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Lock screen: circular

private struct AccessoryCircularView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.00, green: 0.55, blue: 0.05).opacity(0.18))
            WidgetOrb(size: 32)
        }
        .widgetURL(URL(string: "maxapp://listen"))
    }
}

// MARK: - Lock screen: rectangular

private struct AccessoryRectangularView: View {
    let entry: MaxWidgetEntry

    var body: some View {
        HStack(spacing: 8) {
            WidgetOrb(size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("Max")
                    .font(.system(size: 13, weight: .bold))
                Text(entry.lastMessage)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "maxapp://listen"))
    }
}

// MARK: - Lock screen: inline

private struct AccessoryInlineView: View {
    let entry: MaxWidgetEntry

    var body: some View {
        Label {
            Text(entry.lastMessage)
                .lineLimit(1)
        } icon: {
            Image(systemName: "waveform.circle.fill")
        }
        .widgetURL(URL(string: "maxapp://listen"))
    }
}

// MARK: - Widget entry view (routes to size-specific view)

struct MaxWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MaxWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView()
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget configuration

struct MaxWidget: Widget {
    let kind = "MaxWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MaxWidgetProvider()) { entry in
            MaxWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 0.06, green: 0.04, blue: 0.02), for: .widget)
        }
        .configurationDisplayName("Max")
        .description("Talk to Max or see your last conversation.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Widget bundle (@main entry point for the extension)

@main
struct MaxWidgetBundle: WidgetBundle {
    var body: some Widget {
        MaxWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MaxWidget()
} timeline: {
    MaxWidgetEntry(date: .now, lastMessage: "Ready to help you.", lastMessageAt: nil)
}

#Preview("Medium", as: .systemMedium) {
    MaxWidget()
} timeline: {
    MaxWidgetEntry(date: .now, lastMessage: "You have 3 meetings today. Your 2 PM with Sarah is the most important.", lastMessageAt: Date(timeIntervalSinceNow: -120))
}

#Preview("Lock Screen Circular", as: .accessoryCircular) {
    MaxWidget()
} timeline: {
    MaxWidgetEntry(date: .now, lastMessage: "Ready.", lastMessageAt: nil)
}

#Preview("Lock Screen Rectangular", as: .accessoryRectangular) {
    MaxWidget()
} timeline: {
    MaxWidgetEntry(date: .now, lastMessage: "You have 3 meetings today.", lastMessageAt: Date(timeIntervalSinceNow: -300))
}

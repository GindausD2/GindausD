import SwiftUI
import WidgetKit

private struct CaptureEntry: TimelineEntry {
    let date: Date
}

private struct CaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaptureEntry { CaptureEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (CaptureEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaptureEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .never))
    }
}

@main
struct MaxWatchCaptureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MaxWatchCapture", provider: CaptureProvider()) { _ in
            CaptureComplicationView()
        }
        .configurationDisplayName("Save a thought")
        .description("Open Max’s thought recorder.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct CaptureComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                Label("Save a thought", systemImage: "waveform")
                    .font(.headline)
            } else {
                Image(systemName: "waveform")
                    .font(.title3.bold())
                    .accessibilityLabel("Save a thought")
            }
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        .widgetURL(URL(string: "max-watch://capture"))
    }
}

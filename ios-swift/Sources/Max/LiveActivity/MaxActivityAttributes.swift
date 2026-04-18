import ActivityKit
import Foundation

// MARK: - MaxActivityAttributes
//
// Shared model used by both the main app (to start/update/end activities)
// and the MaxLiveActivity widget extension (to render the Dynamic Island UI).
//
// The widget extension target in Xcode must also include this file or
// import it from a shared framework.

public struct MaxActivityAttributes: ActivityAttributes {
    public typealias MaxActivityState = ContentState

    // MARK: - Dynamic content (updated during the activity's lifetime)

    public struct ContentState: Codable, Hashable {
        /// Current conversation phase shown in the Dynamic Island
        public var phase: Phase
        /// Latest transcript snippet (truncated to ~60 chars for compact display)
        public var snippet: String
        /// Optional action card shown after a tool executes (Uber, flight, email, etc.)
        public var toolCard: ToolCard?

        public init(phase: Phase, snippet: String, toolCard: ToolCard? = nil) {
            self.phase = phase
            self.snippet = snippet
            self.toolCard = toolCard
        }

        public enum Phase: String, Codable, Hashable {
            case idle      // waiting for input
            case listening // mic is active, recording user speech
            case thinking  // waiting for Claude's response
            case speaking  // TTS is playing the response

            public var label: String {
                switch self {
                case .idle:      return "Ready"
                case .listening: return "Listening…"
                case .thinking:  return "Thinking…"
                case .speaking:  return "Speaking…"
                }
            }

            public var symbolName: String {
                switch self {
                case .idle:      return "waveform"
                case .listening: return "mic.fill"
                case .thinking:  return "brain"
                case .speaking:  return "speaker.wave.2.fill"
                }
            }
        }

        // MARK: - Tool Action Card

        /// A compact card displayed in the Dynamic Island after a tool action completes.
        public struct ToolCard: Codable, Hashable {
            public enum Kind: String, Codable, Hashable {
                case uber, flight, email, call, calendar, directions, news, reminder
            }
            /// Card type — drives the icon tint and compact trailing icon
            public var kind: Kind
            /// Bold primary line (e.g. "LHR → JFK")
            public var line1: String
            /// Dim secondary line (e.g. "Apr 22 · 2 passengers")
            public var line2: String
            /// SF Symbol name for the leading icon
            public var iconName: String

            public init(kind: Kind, line1: String, line2: String, iconName: String) {
                self.kind = kind
                self.line1 = line1
                self.line2 = line2
                self.iconName = iconName
            }
        }
    }

    // MARK: - Static attributes (set once at activity start, never change)

    /// User-visible session label (e.g. "Max is listening")
    public var sessionLabel: String

    public init(sessionLabel: String = "Max AI") {
        self.sessionLabel = sessionLabel
    }
}

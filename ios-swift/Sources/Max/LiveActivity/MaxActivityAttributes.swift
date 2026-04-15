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
    }

    // MARK: - Static attributes (set once at activity start, never change)

    /// User-visible session label (e.g. "Max is listening")
    public var sessionLabel: String

    public init(sessionLabel: String = "Max AI") {
        self.sessionLabel = sessionLabel
    }
}

import Foundation

/// Retains an explicit request across cold launch and initial sign-in, then consumes it once.
/// Requests never bypass Home's access gate or start a microphone in the background.
@MainActor
enum MaxShortcutRequest {
    enum Action: Equatable { case voice, island }
    private static let voiceKey = "max.pendingVoiceActivation"
    private static let islandKey = "max.pendingIslandActivation"
    private static let requestedAtKey = "max.shortcutRequestedAt"
    private static let lifetime: TimeInterval = 5 * 60

    static func enqueue(_ action: Action, defaults: UserDefaults = .standard, notify: Bool = true, now: Date = Date()) {
        clear(defaults: defaults)
        defaults.set(true, forKey: action == .voice ? voiceKey : islandKey)
        defaults.set(now, forKey: requestedAtKey)
        if notify { NotificationCenter.default.post(name: .maxWidgetActivate, object: nil) }
    }

    static func takePending(canEnterHome: Bool, isActive: Bool, defaults: UserDefaults = .standard, now: Date = Date()) -> Action? {
        guard canEnterHome, isActive else { return nil }
        guard let requestedAt = defaults.object(forKey: requestedAtKey) as? Date,
              (0...lifetime).contains(now.timeIntervalSince(requestedAt)) else {
            clear(defaults: defaults)
            return nil
        }
        let action: Action?
        if defaults.bool(forKey: voiceKey) { action = .voice }
        else if defaults.bool(forKey: islandKey) { action = .island }
        else { return nil }
        clear(defaults: defaults)
        return action
    }

    static func accountDidChange(hadPreviousUser: Bool, defaults: UserDefaults = .standard) {
        // Initial session restoration/sign-in may complete the request. Sign-out or switching
        // an existing account must discard it instead of carrying it to another person.
        if hadPreviousUser { clear(defaults: defaults) }
    }

    private static func clear(defaults: UserDefaults) {
        defaults.removeObject(forKey: voiceKey)
        defaults.removeObject(forKey: islandKey)
        defaults.removeObject(forKey: requestedAtKey)
    }
}

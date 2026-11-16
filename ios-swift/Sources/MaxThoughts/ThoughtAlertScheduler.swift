import Foundation
import SwiftUI
import UserNotifications
#if os(iOS) && canImport(AlarmKit)
import AlarmKit
#endif

enum ThoughtAlertKind: String, Codable, Identifiable {
    case reminder, alarm
    var id: Self { self }
    var title: String { self == .alarm ? "Set alarm" : "Remind me" }
    var name: String { self == .alarm ? "Alarm" : "Reminder" }
}

struct ScheduledThoughtAlert: Codable, Equatable {
    let id: UUID
    let thoughtID: UUID
    let kind: ThoughtAlertKind
    let date: Date
    var confirmed = false
    var label: String? = nil
}

enum ThoughtAlertError: LocalizedError {
    case timePassed, alarmsUnavailable, alarmPermission, notificationPermission

    var errorDescription: String? {
        switch self {
        case .timePassed: "Choose a time in the future."
        case .alarmsUnavailable: "Alarms aren’t available on this device."
        case .alarmPermission: "Allow alarms for Max in Settings to schedule one."
        case .notificationPermission: "Allow notifications for Max in Settings to schedule a reminder."
        }
    }
}

@MainActor
enum ThoughtAlertScheduler {
    static func schedule(_ alert: ScheduledThoughtAlert) async throws {
        if alert.kind == .alarm {
            #if os(iOS) && canImport(AlarmKit)
            guard #available(iOS 26.0, *), !ProcessInfo.processInfo.isiOSAppOnMac else {
                throw ThoughtAlertError.alarmsUnavailable
            }
            let manager = AlarmManager.shared
            let authorization = manager.authorizationState == .notDetermined
                ? try await manager.requestAuthorization() : manager.authorizationState
            guard authorization == .authorized else { throw ThoughtAlertError.alarmPermission }
            guard alert.date > Date.now else { throw ThoughtAlertError.timePassed }
            try Task.checkCancellation()
            let presentation = AlarmPresentation(alert: .init(
                title: LocalizedStringResource(stringLiteral: alert.label ?? "Max thought alarm"),
                stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill")
            ))
            let attributes = AlarmAttributes(presentation: presentation, metadata: ThoughtAlarmMetadata(), tintColor: .cyan)
            let configuration = AlarmManager.AlarmConfiguration(
                schedule: .fixed(alert.date), attributes: attributes, sound: .default
            )
            _ = try await manager.schedule(id: alert.id, configuration: configuration)
            #else
            throw ThoughtAlertError.alarmsUnavailable
            #endif
        } else {
            let center = UNUserNotificationCenter.current()
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                throw ThoughtAlertError.notificationPermission
            }
            let remaining = alert.date.timeIntervalSinceNow
            guard remaining > 0 else { throw ThoughtAlertError.timePassed }
            try Task.checkCancellation()
            let content = UNMutableNotificationContent()
            content.title = "Max thought reminder"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, remaining), repeats: false)
            try await center.add(.init(identifier: alert.id.uuidString, content: content, trigger: trigger))
        }
    }

    static func hasAlarm(id: UUID) throws -> Bool {
        #if os(iOS) && canImport(AlarmKit)
        guard #available(iOS 26.0, *), !ProcessInfo.processInfo.isiOSAppOnMac else {
            throw ThoughtAlertError.alarmsUnavailable
        }
        let manager = AlarmManager.shared
        guard manager.authorizationState == .authorized else { throw ThoughtAlertError.alarmPermission }
        return try manager.alarms.contains { $0.id == id }
        #else
        throw ThoughtAlertError.alarmsUnavailable
        #endif
    }

    static func cancel(_ alert: ScheduledThoughtAlert) throws {
        if alert.kind == .alarm {
            #if os(iOS) && canImport(AlarmKit)
            guard #available(iOS 26.0, *), !ProcessInfo.processInfo.isiOSAppOnMac else {
                throw ThoughtAlertError.alarmsUnavailable
            }
            let manager = AlarmManager.shared
            if try manager.alarms.contains(where: { $0.id == alert.id }) {
                try manager.cancel(id: alert.id)
            }
            #else
            throw ThoughtAlertError.alarmsUnavailable
            #endif
        } else {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [alert.id.uuidString])
            center.removeDeliveredNotifications(withIdentifiers: [alert.id.uuidString])
        }
    }
}

#if os(iOS) && canImport(AlarmKit)
@available(iOS 26.0, *)
private struct ThoughtAlarmMetadata: AlarmMetadata {}
#endif

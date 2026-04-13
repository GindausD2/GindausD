import Foundation
import UserNotifications

final class ToolsService {
    static let shared = ToolsService()

    private init() {}

    // MARK: - Tool Executor

    func execute(name: String, input: [String: Any]) async -> String {
        switch name {
        case "get_datetime":
            return getDatetime()
        case "save_note":
            return saveNote(input: input)
        case "get_notes":
            return getNotes()
        case "delete_note":
            return deleteNote(input: input)
        case "remember_fact":
            return rememberFact(input: input)
        case "recall_facts":
            return recallFacts()
        case "schedule_reminder":
            return await scheduleReminder(input: input)
        case "get_reminders":
            return getReminders()
        default:
            return encodeResult(["error": "Unknown tool: \(name)"])
        }
    }

    // MARK: - Tool Implementations

    private func getDatetime() -> String {
        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let humanFormatter = DateFormatter()
        humanFormatter.dateStyle = .full
        humanFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        let result: [String: String] = [
            "iso": isoFormatter.string(from: now),
            "humanDate": humanFormatter.string(from: now),
            "time": timeFormatter.string(from: now),
            "timezone": TimeZone.current.identifier,
            "dayOfWeek": Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: now) - 1]
        ]
        return encodeResult(result)
    }

    private func saveNote(input: [String: Any]) -> String {
        guard let title = input["title"] as? String,
              let content = input["content"] as? String else {
            return encodeResult(["error": "Missing title or content"])
        }
        let note = StorageService.shared.saveNote(title: title, content: content)
        return encodeResult([
            "success": true,
            "id": note.id,
            "title": note.title,
            "message": "Note '\(title)' saved successfully"
        ])
    }

    private func getNotes() -> String {
        let notes = StorageService.shared.loadNotes()
        let mapped = notes.map { note -> [String: Any] in
            let isoFormatter = ISO8601DateFormatter()
            return [
                "id": note.id,
                "title": note.title,
                "content": note.content,
                "createdAt": isoFormatter.string(from: note.createdAt),
                "updatedAt": isoFormatter.string(from: note.updatedAt)
            ]
        }
        return encodeResult(["notes": mapped, "count": notes.count])
    }

    private func deleteNote(input: [String: Any]) -> String {
        guard let id = input["id"] as? String else {
            return encodeResult(["error": "Missing note ID"])
        }
        StorageService.shared.deleteNote(id: id)
        return encodeResult(["success": true, "message": "Note deleted successfully"])
    }

    private func rememberFact(input: [String: Any]) -> String {
        guard let key = input["key"] as? String,
              let value = input["value"] as? String else {
            return encodeResult(["error": "Missing key or value"])
        }
        StorageService.shared.rememberFact(key: key, value: value)
        return encodeResult([
            "success": true,
            "message": "Remembered: \(key) = \(value)"
        ])
    }

    private func recallFacts() -> String {
        let memories = StorageService.shared.recallFacts()
        let isoFormatter = ISO8601DateFormatter()
        let mapped = memories.map { mem -> [String: Any] in
            [
                "key": mem.key,
                "value": mem.value,
                "updatedAt": isoFormatter.string(from: mem.updatedAt)
            ]
        }
        return encodeResult(["facts": mapped, "count": memories.count])
    }

    private func scheduleReminder(input: [String: Any]) async -> String {
        let title = input["title"] as? String ?? "Reminder"
        let body = input["body"] as? String ?? ""
        let minutesStr = input["minutesFromNow"] as? String ?? "0"
        let minutes = Double(minutesStr) ?? 0

        let center = UNUserNotificationCenter.current()

        // Request permission if needed
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            return encodeResult(["error": "Notification permission denied"])
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let fireDate = Date().addingTimeInterval(minutes * 60)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, minutes * 60),
            repeats: false
        )

        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await center.add(request)
            let reminder = Reminder(id: id, title: title, body: body, fireDate: fireDate)
            StorageService.shared.saveReminder(reminder)
            return encodeResult([
                "success": true,
                "id": id,
                "message": "Reminder set for \(Int(minutes)) minute(s) from now"
            ])
        } catch {
            return encodeResult(["error": "Failed to schedule reminder: \(error.localizedDescription)"])
        }
    }

    private func getReminders() -> String {
        let reminders = StorageService.shared.loadReminders()
        let isoFormatter = ISO8601DateFormatter()
        let now = Date()
        let upcoming = reminders.filter { $0.fireDate > now }
        let mapped = upcoming.map { rem -> [String: Any] in
            [
                "id": rem.id,
                "title": rem.title,
                "body": rem.body,
                "fireDate": isoFormatter.string(from: rem.fireDate)
            ]
        }
        return encodeResult(["reminders": mapped, "count": upcoming.count])
    }

    // MARK: - Encoding Helper

    private func encodeResult(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
              let string = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"Encoding failed\"}"
        }
        return string
    }
}

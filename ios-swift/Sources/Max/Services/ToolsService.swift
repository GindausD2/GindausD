import EventKit
import Foundation
import UIKit
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
        case "book_flight":
            return await bookFlight(input: input)
        case "book_uber":
            return await bookUber(input: input)
        case "compose_email":
            return await composeEmail(input: input)
        case "make_call":
            return await makeCall(input: input)
        case "read_news":
            return await readNews(input: input)
        case "create_calendar_event":
            return await createCalendarEvent(input: input)
        case "get_calendar_events":
            return await getCalendarEvents(input: input)
        case "get_directions":
            return await getDirections(input: input)
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

            await MainActor.run {
                LiveActivityService.shared.showToolCard(ToolCard(
                    kind: .reminder,
                    line1: title,
                    line2: "Reminder in \(Int(minutes)) min",
                    iconName: "bell.fill"
                ))
            }

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

    private func bookFlight(input: [String: Any]) async -> String {
        guard let origin = input["origin"] as? String,
              let destination = input["destination"] as? String,
              let date = input["date"] as? String else {
            return encodeResult(["error": "Missing origin, destination, or date"])
        }
        let passengers = input["passengers"] as? String ?? "1"

        let originEnc = origin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? origin
        let destEnc = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        let kayakURLStr = "https://www.kayak.com/flights/\(originEnc)-\(destEnc)/\(date)/\(passengers)adults"

        await openURL(kayakURLStr)

        await MainActor.run {
            LiveActivityService.shared.showToolCard(ToolCard(
                kind: .flight,
                line1: "\(origin) → \(destination)",
                line2: "\(date) · \(passengers) pax",
                iconName: "airplane"
            ))
        }

        return encodeResult([
            "success": true,
            "message": "Opening flight search for \(origin) → \(destination) on \(date) for \(passengers) passenger(s).",
            "url": kayakURLStr
        ])
    }

    private func bookUber(input: [String: Any]) async -> String {
        guard let pickup = input["pickup"] as? String,
              let dropoff = input["dropoff"] as? String else {
            return encodeResult(["error": "Missing pickup or dropoff"])
        }

        let pickupEnc = pickup.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? pickup
        let dropoffEnc = dropoff.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dropoff

        let uberDeepLink = "uber://?action=setPickup&pickup[nickname]=\(pickupEnc)&dropoff[nickname]=\(dropoffEnc)"
        let uberWebURL   = "https://m.uber.com/ul/?action=setPickup&pickup[nickname]=\(pickupEnc)&dropoff[nickname]=\(dropoffEnc)"

        let opened = await openURL(uberDeepLink)
        if !opened { await openURL(uberWebURL) }

        await MainActor.run {
            LiveActivityService.shared.showToolCard(ToolCard(
                kind: .uber,
                line1: "\(pickup) → \(dropoff)",
                line2: "Opening Uber…",
                iconName: "car.fill"
            ))
        }

        return encodeResult([
            "success": true,
            "message": "Opening Uber to book a ride from \(pickup) to \(dropoff)."
        ])
    }

    private func composeEmail(input: [String: Any]) async -> String {
        guard let to = input["to"] as? String,
              let subject = input["subject"] as? String,
              let body = input["body"] as? String else {
            return encodeResult(["error": "Missing to, subject, or body"])
        }

        let toEnc      = to.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? to
        let subjectEnc = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let bodyEnc    = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        let mailtoURL  = "mailto:\(toEnc)?subject=\(subjectEnc)&body=\(bodyEnc)"

        await openURL(mailtoURL)

        await MainActor.run {
            LiveActivityService.shared.showToolCard(ToolCard(
                kind: .email,
                line1: "To: \(to)",
                line2: subject,
                iconName: "envelope.fill"
            ))
        }

        return encodeResult([
            "success": true,
            "message": "Opening email compose to \(to) with subject '\(subject)'."
        ])
    }

    private func makeCall(input: [String: Any]) async -> String {
        guard let phoneNumber = input["phoneNumber"] as? String else {
            return encodeResult(["error": "Missing phoneNumber"])
        }
        let contactName = input["contactName"] as? String ?? phoneNumber
        let digits = phoneNumber.filter(\.isNumber)
        guard !digits.isEmpty else {
            return encodeResult(["error": "Invalid phone number"])
        }

        await openURL("tel://\(digits)")

        await MainActor.run {
            LiveActivityService.shared.showToolCard(ToolCard(
                kind: .call,
                line1: contactName,
                line2: "Calling…",
                iconName: "phone.fill"
            ))
        }

        return encodeResult([
            "success": true,
            "message": "Calling \(contactName)…"
        ])
    }

    // MARK: - New Tools

    private func readNews(input: [String: Any]) async -> String {
        let topic = input["topic"] as? String ?? ""
        let feedURL = URL(string: "https://feeds.bbci.co.uk/news/rss.xml")!

        do {
            let (data, _) = try await URLSession.shared.data(from: feedURL)
            let headlines = parseRSSHeadlines(data: data, limit: 5)

            if let first = headlines.first {
                await MainActor.run {
                    LiveActivityService.shared.showToolCard(ToolCard(
                        kind: .news,
                        line1: first,
                        line2: "BBC News",
                        iconName: "newspaper.fill"
                    ))
                }
            }

            return encodeResult([
                "success": true,
                "headlines": headlines,
                "source": "BBC News",
                "topic": topic.isEmpty ? "Top Stories" : topic
            ])
        } catch {
            return encodeResult(["error": "Could not fetch news: \(error.localizedDescription)"])
        }
    }

    private func createCalendarEvent(input: [String: Any]) async -> String {
        guard let title = input["title"] as? String,
              let startISO = input["startISO"] as? String else {
            return encodeResult(["error": "Missing title or startISO"])
        }

        let durationStr = input["durationMinutes"] as? String ?? "60"
        let duration = (Double(durationStr) ?? 60) * 60
        let notes = input["notes"] as? String

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatter2 = ISO8601DateFormatter()
        isoFormatter2.formatOptions = [.withInternetDateTime]

        guard let startDate = isoFormatter.date(from: startISO) ?? isoFormatter2.date(from: startISO) else {
            return encodeResult(["error": "Invalid startISO date format. Use ISO 8601 (e.g. 2026-04-20T15:00:00Z)"])
        }

        let store = EKEventStore()
        let granted: Bool

        if #available(iOS 17.0, *) {
            granted = (try? await store.requestWriteOnlyAccessToEvents()) ?? false
        } else {
            granted = await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { ok, _ in continuation.resume(returning: ok) }
            }
        }

        guard granted else {
            return encodeResult(["error": "Calendar access denied"])
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent)

            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short

            await MainActor.run {
                LiveActivityService.shared.showToolCard(ToolCard(
                    kind: .calendar,
                    line1: title,
                    line2: displayFormatter.string(from: startDate),
                    iconName: "calendar.badge.plus"
                ))
            }

            return encodeResult([
                "success": true,
                "message": "Calendar event '\(title)' created for \(displayFormatter.string(from: startDate))."
            ])
        } catch {
            return encodeResult(["error": "Failed to save event: \(error.localizedDescription)"])
        }
    }

    private func getCalendarEvents(input: [String: Any]) async -> String {
        let daysStr = input["daysAhead"] as? String ?? "7"
        let days = Double(daysStr) ?? 7

        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            granted = await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { ok, _ in continuation.resume(returning: ok) }
            }
        }
        guard granted else {
            return encodeResult(["error": "Calendar access denied"])
        }

        let now = Date()
        let end = now.addingTimeInterval(days * 86400)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short

        let meetingPattern = try? NSRegularExpression(
            pattern: #"https?://[^\s]*(?:zoom\.us|meet\.google\.com|teams\.microsoft\.com)[^\s]*"#
        )

        func extractMeetingLink(from text: String?) -> String? {
            guard let text, let pattern = meetingPattern else { return nil }
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, range: range),
               let swiftRange = Range(match.range, in: text) {
                return String(text[swiftRange])
            }
            return nil
        }

        let mapped: [[String: String]] = events.prefix(20).map { ev in
            var dict: [String: String] = [
                "title": ev.title ?? "Untitled",
                "start": displayFormatter.string(from: ev.startDate),
                "end": displayFormatter.string(from: ev.endDate),
            ]
            if let loc = ev.location, !loc.isEmpty { dict["location"] = loc }
            // Prefer event URL, then scan notes for meeting link
            let linkSource = ev.url?.absoluteString ?? ev.notes
            if let link = extractMeetingLink(from: linkSource) { dict["meetingLink"] = link }
            if let notes = ev.notes, !notes.isEmpty { dict["notes"] = String(notes.prefix(200)) }
            return dict
        }

        return encodeResult(["events": mapped, "count": mapped.count, "daysAhead": Int(days)])
    }

    private func getDirections(input: [String: Any]) async -> String {
        guard let destination = input["destination"] as? String else {
            return encodeResult(["error": "Missing destination"])
        }

        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        await openURL("maps://?q=\(encoded)")

        await MainActor.run {
            LiveActivityService.shared.showToolCard(ToolCard(
                kind: .directions,
                line1: destination,
                line2: "Opening Maps…",
                iconName: "map.fill"
            ))
        }

        return encodeResult([
            "success": true,
            "message": "Opening Maps with directions to \(destination)."
        ])
    }

    // MARK: - RSS Parser

    private func parseRSSHeadlines(data: Data, limit: Int) -> [String] {
        let parser = RSSParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return Array(parser.headlines.prefix(limit))
    }

    // MARK: - URL Helper

    @discardableResult
    private func openURL(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return await MainActor.run {
            UIApplication.shared.canOpenURL(url) ? (UIApplication.shared.open(url), true).1 : false
        }
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

// MARK: - RSS Parser Helper

private final class RSSParser: NSObject, XMLParserDelegate {
    var headlines: [String] = []

    private var currentElement = ""
    private var currentText = ""
    private var insideItem = false
    private var channelTitleSkipped = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""
        if elementName == "item" { insideItem = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "title" {
            let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                if !channelTitleSkipped && !insideItem {
                    // Skip the feed-level channel title
                    channelTitleSkipped = true
                } else if insideItem {
                    headlines.append(text)
                }
            }
        }
        if elementName == "item" { insideItem = false }
        currentText = ""
    }
}

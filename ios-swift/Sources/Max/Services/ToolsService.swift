import CoreLocation
import WeatherKit
import Contacts
import EventKit
import Foundation
import UIKit
import UserNotifications

@MainActor
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
            return await getReminders()
        case "save_place":
            return await savePlace(input: input)
        case "schedule_location_reminder":
            return await scheduleLocationReminder(input: input)
        case "schedule_context_reminder":
            return scheduleContextReminder(input: input)
        case "get_weather":
            return await getWeather(input: input)
        case "book_flight", "book_uber":
            return encodeResult(["error": "Booking is not available in Max V1."])
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
        case "recall_places":
            return recallPlaces()
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
        let scope = StorageService.shared.accountScope
        let title = input["title"] as? String ?? "Reminder"
        let body = input["body"] as? String ?? ""
        let minutesStr = input["minutesFromNow"] as? String ?? ""
        let minutes = Double(minutesStr) ?? .nan
        let absoluteDate = (input["fireAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        guard !(input["fireAt"] != nil && input["minutesFromNow"] != nil), input["fireAt"] == nil || absoluteDate != nil else {
            return encodeResult(["error": "Choose one valid time: fireAt or minutesFromNow."])
        }
        let delay = absoluteDate.map { $0.timeIntervalSinceNow } ?? minutes * 60
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, delay.isFinite, delay > 0, delay <= 365 * 86400 else {
            return encodeResult(["error": "Please choose a valid future reminder time within a year."])
        }

        let fireDate = absoluteDate ?? Date().addingTimeInterval(delay)
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            return encodeResult(["error": "Notification permission denied"])
        }
        let remaining = fireDate.timeIntervalSinceNow
        guard remaining > 0, !Task.isCancelled, StorageService.shared.accountScope == scope else {
            return encodeResult(["error": "That time has passed or your session changed. Please choose a new reminder time."])
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, remaining),
            repeats: false
        )

        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await center.add(request)
            let reminder = Reminder(id: id, title: title, body: body, fireDate: fireDate)
            guard !Task.isCancelled, StorageService.shared.accountScope == scope else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
                return encodeResult(["error": "Your session changed. Please try again."])
            }
            StorageService.shared.saveReminder(reminder, scope: scope)

            await MainActor.run {
                LiveActivityService.shared.showToolCard(ToolCard(
                    kind: .reminder,
                    line1: title,
                    line2: "Reminder in \(Int(ceil(delay / 60))) min",
                    iconName: "bell.fill"
                ))
            }

            return encodeResult([
                "success": true,
                "id": id,
                "message": "Reminder set for \(Int(ceil(delay / 60))) minute(s) from now"
            ])
        } catch {
            return encodeResult(["error": "Failed to schedule reminder: \(error.localizedDescription)"])
        }
    }

    private func getReminders() async -> String {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let pendingIDs = Set(pending.map(\.identifier))
        let reminders = StorageService.shared.loadReminders()
        let isoFormatter = ISO8601DateFormatter()
        let now = Date()
        let upcoming = reminders.filter { $0.triggerKind == "context" || ($0.fireDate > now && pendingIDs.contains($0.id)) }
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
        let contactName = input["contactName"] as? String
        var rawNumber   = input["phoneNumber"]  as? String

        // If no number given, look it up from Contacts by name
        if (rawNumber == nil || rawNumber!.isEmpty), let name = contactName {
            rawNumber = await lookupPhoneNumber(for: name)
            if rawNumber == nil {
                return encodeResult(["error": "Could not find a phone number for \(name) in Contacts"])
            }
        }

        guard let rawNumber, !rawNumber.isEmpty else {
            return encodeResult(["error": "Provide either phoneNumber or contactName"])
        }

        let digits = rawNumber.filter(\.isNumber)
        guard !digits.isEmpty else {
            return encodeResult(["error": "Invalid phone number"])
        }

        let displayName = contactName ?? rawNumber
        await openURL("tel://\(digits)")

        await MainActor.run {
            LiveActivityService.shared.showToolCard(ToolCard(
                kind: .call,
                line1: displayName,
                line2: "Calling…",
                iconName: "phone.fill"
            ))
        }

        return encodeResult(["success": true, "message": "Calling \(displayName)…"])
    }

    private func lookupPhoneNumber(for name: String) async -> String? {
        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        guard granted else { return nil }

        let pred = CNContact.predicateForContacts(matchingName: name)
        let keys = [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let contacts = (try? store.unifiedContacts(matching: pred, keysToFetch: keys)) ?? []

        return contacts.first?.phoneNumbers.first?.value.stringValue
    }

    // MARK: - New Tools

    private func readNews(input: [String: Any]) async -> String {
        let topic = (input["topic"] as? String ?? "").lowercased()

        let feedMap: [String: String] = [
            "tech": "technology", "technology": "technology",
            "business": "business", "finance": "business", "economy": "business",
            "world": "world", "international": "world",
            "science": "science_and_environment", "environment": "science_and_environment",
            "health": "health", "medical": "health",
            "sport": "sport", "sports": "sport",
            "entertainment": "entertainment_and_arts", "arts": "entertainment_and_arts",
            "politics": "politics", "political": "politics"
        ]
        let path = feedMap.first(where: { topic.contains($0.key) })?.value
        let feedURLString = path.map { "https://feeds.bbci.co.uk/news/\($0)/rss.xml" }
            ?? "https://feeds.bbci.co.uk/news/rss.xml"
        let feedURL = URL(string: feedURLString)!

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

    private func recallPlaces() -> String {
        let visits = StorageService.shared.loadPlaceVisits()
            .sorted { $0.visitedAt > $1.visitedAt }
            .prefix(20)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let mapped: [[String: String]] = visits.map { v in
            var d: [String: String] = [
                "destination": v.destination,
                "when": formatter.string(from: v.visitedAt)
            ]
            if let p = v.person { d["person"] = p }
            if let n = v.note   { d["note"]   = n }
            return d
        }
        return encodeResult(["visits": mapped, "count": mapped.count])
    }

    private func getDirections(input: [String: Any]) async -> String {
        guard let destination = input["destination"] as? String else {
            return encodeResult(["error": "Missing destination"])
        }

        let person = input["person"] as? String
        let note   = input["note"]   as? String

        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        await openURL("maps://?q=\(encoded)")

        // Save to place memory
        StorageService.shared.savePlaceVisit(
            PlaceVisit(destination: destination, person: person, note: note)
        )

        await MainActor.run {
            LiveActivityService.shared.showToolCard(ToolCard(
                kind: .directions,
                line1: destination,
                line2: person.map { "Meeting \($0)" } ?? "Opening Maps…",
                iconName: "map.fill"
            ))
        }

        return encodeResult([
            "success": true,
            "message": "Opening Maps with directions to \(destination)."
        ])
    }

    // MARK: - V1 saved places, weather, and reminder triggers

    private func savePlace(input: [String: Any]) async -> String {
        let scope = StorageService.shared.accountScope
        guard let address = input["address"] as? String, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let name = input["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return encodeResult(["error": "Give the place a name and address."])
        }
        do {
            let matches = try await CLGeocoder().geocodeAddressString(address)
            guard matches.count == 1, let coordinate = matches.first?.location?.coordinate else {
                return encodeResult(["error": "That address is ambiguous. Include the street, city, and country."])
            }
            let visit = PlaceVisit(destination: name, note: address, latitude: coordinate.latitude, longitude: coordinate.longitude)
            guard !Task.isCancelled, StorageService.shared.accountScope == scope else { return encodeResult(["error": "Your session changed. Please try again."]) }
            StorageService.shared.savePlaceVisit(visit, scope: scope)
            return encodeResult(["success": true, "id": visit.id, "message": "Saved \(name). This is a saved place, not a detected visit."])
        } catch { return encodeResult(["error": "Couldn't locate that address. Please try a fuller address."]) }
    }

    private func scheduleLocationReminder(input: [String: Any]) async -> String {
        let scope = StorageService.shared.accountScope
        guard let name = input["placeName"] as? String, let title = input["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return encodeResult(["error": "Provide a reminder and the name of a saved place."])
        }
        let matches = StorageService.shared.loadPlaceVisits().filter { $0.destination.caseInsensitiveCompare(name) == .orderedSame && $0.latitude != nil && $0.longitude != nil }
        guard matches.count == 1, let place = matches.first, let latitude = place.latitude, let longitude = place.longitude else {
            return encodeResult(["error": "Save a place with a unique name and address first."])
        }
        guard await LocationAccessService.shared.authorize(), CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            return encodeResult(["error": "Allow location access in iPhone Settings to use arrival reminders."])
        }
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return encodeResult(["error": "Notification permission denied."]) }
        let id = UUID().uuidString
        let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: 200, identifier: id)
        region.notifyOnEntry = true; region.notifyOnExit = false
        let content = UNMutableNotificationContent(); content.title = title; content.body = "Arriving at \(name)"; content.sound = .default
        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNLocationNotificationTrigger(region: region, repeats: false)))
            guard !Task.isCancelled, StorageService.shared.accountScope == scope else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
                return encodeResult(["error": "Your session changed. Please try again."])
            }
            StorageService.shared.saveReminder(Reminder(id: id, title: title, body: content.body, fireDate: .distantFuture, triggerKind: "location", placeID: place.id), scope: scope)
            return encodeResult(["success": true, "message": "I'll remind you when iOS detects your arrival at \(name). Location accuracy and device settings affect delivery."])
        } catch { return encodeResult(["error": "Couldn't save that arrival reminder."]) }
    }

    private func scheduleContextReminder(input: [String: Any]) -> String {
        guard let context = input["context"] as? String, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let title = input["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return encodeResult(["error": "Provide a named context and a reminder."])
        }
        StorageService.shared.saveReminder(Reminder(title: title, body: "When you check \(context) in Max", fireDate: .distantFuture, triggerKind: "context", contextName: context))
        return encodeResult(["success": true, "message": "Saved. This reminder appears when you explicitly check \(context) in Max; it does not monitor your activity."])
    }

    private func getWeather(input: [String: Any]) async -> String {
        let saved = StorageService.shared.loadPlaceVisits()
        let place: PlaceVisit?
        if let name = input["placeName"] as? String { place = saved.last { $0.destination.caseInsensitiveCompare(name) == .orderedSame } }
        else { place = saved.last { $0.latitude != nil && $0.longitude != nil } }
        guard let place, let lat = place.latitude, let lon = place.longitude else { return encodeResult(["error": "Save a place with an address to enable weather."]) }
        do {
            let weather = try await WeatherService.shared.weather(for: CLLocation(latitude: lat, longitude: lon))
            let temperature = weather.currentWeather.temperature.converted(to: .celsius).value
            return encodeResult(["place": place.destination, "temperatureC": temperature, "condition": String(describing: weather.currentWeather.condition), "source": "Apple Weather", "attributionURL": "https://weatherkit.apple.com/legal-attribution.html"])
        } catch { return encodeResult(["error": "Weather is unavailable. WeatherKit must be enabled for the release build."]) }
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

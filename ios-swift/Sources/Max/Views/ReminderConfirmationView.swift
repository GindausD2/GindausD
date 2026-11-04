import SwiftUI

/// Displays an already-saved reminder. Scheduling remains in the creation flow.
struct ReminderConfirmationView: View {
    let reminder: Reminder
    let places: [PlaceVisit]
    var timeZone: TimeZone = .current
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder saved") {
                    Label(reminder.title, systemImage: "checkmark.circle.fill")
                        .font(.headline).foregroundStyle(Color(hex: "#315E73"))
                    Text(reminder.triggerSummary(place: places.first { $0.id == reminder.placeID }, timeZone: timeZone))
                    if reminder.triggerKind == "location", let address = places.first(where: { $0.id == reminder.placeID })?.note {
                        Text(address).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if reminder.triggerKind != "location", reminder.triggerKind != "context" {
                        Text("Time zone: \(timeZone.identifier)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Reminder saved")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: onDone) } }
        }
    }
}

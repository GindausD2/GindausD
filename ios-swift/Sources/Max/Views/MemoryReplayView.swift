import SwiftUI

struct MemoryReplayView: View {
    let eventID: String
    let scope: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var voice = VoiceService.shared
    @State private var event: LifeEvent?
    @State private var selection = "event"
    @State private var error: String?
    @State private var confirmForget = false
    private let store = StorageService.shared
    private var cards: [MemoryReplayCard] { event.map { MemoryReplay.cards(for: $0) } ?? [] }

    var body: some View {
        NavigationStack {
            ZStack {
                CompanionCanvas()
                if let event {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("A recap of your saved memory").font(.headline)
                        Text("Source cards and optional narration. This is not a recording or footage of the event.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(event.attended ? "Attendance confirmed by you" : "Planned · attendance unconfirmed")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color(hex: "#315E73"))
                        TabView(selection: $selection) {
                            ForEach(cards) { card in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 20) {
                                        Image(systemName: card.symbol).font(.largeTitle).foregroundStyle(Color(hex: "#315E73"))
                                        Text(card.title).font(.title2.weight(.semibold))
                                        Text(card.text).font(.body).textSelection(.enabled)
                                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                                }.glassCard(cornerRadius: 28).padding(.bottom, 30).tag(card.id)
                            }
                        }.tabViewStyle(.page(indexDisplayMode: .always))
                        HStack {
                            Button("Previous") { move(-1) }.disabled(selection == cards.first?.id)
                            Spacer()
                            Text("\((cards.firstIndex { $0.id == selection } ?? 0) + 1) / \(cards.count)").font(.caption)
                            Spacer()
                            Button("Next") { move(1) }.disabled(selection == cards.last?.id)
                        }.frame(minHeight: 44)
                        Button {
                            if voice.isSpeaking { voice.stopSpeaking() }
                            else if let card = cards.first(where: { $0.id == selection }), store.accountScope == scope, store.usesSavedMemory {
                                voice.speak((event.attended ? "User-confirmed event. " : "Planned event. Attendance is unconfirmed. ") + card.title + ". " + card.text)
                            }
                        } label: { Label(voice.isSpeaking ? "Stop narration" : "Read this card", systemImage: voice.isSpeaking ? "stop.fill" : "speaker.wave.2") }
                            .disabled(!store.usesSavedMemory && !voice.isSpeaking).frame(minHeight: 44)
                        Text("Narration uses the existing Max voice service and may send this saved text to Max and OpenAI. Memory pause disables narration.")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("Hiding a card changes the replay only. Its details remain in the saved event and supporting source.")
                            .font(.caption2).foregroundStyle(.secondary)
                        if let error { Text(error).font(.caption).foregroundStyle(.red) }
                    }.padding(20)
                } else {
                    ContentUnavailableView("Memory unavailable", systemImage: "clock", description: Text("The event was forgotten or your account changed. Reopen Life Memory."))
                }
            }.navigationTitle("Memory replay").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { voice.stopSpeaking(); dismiss() } }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(["people", "place", "notes"], id: \.self) { section in
                                Button((event?.hiddenReplaySections?.contains(section) == true ? "Show " : "Hide ") + section) { toggle(section) }
                            }
                            Divider()
                            Button("Forget event", role: .destructive) { confirmForget = true }
                        } label: { Image(systemName: "ellipsis.circle") }.disabled(event == nil)
                    }
                }
                .confirmationDialog("Forget this event?", isPresented: $confirmForget) {
                    Button("Forget event", role: .destructive) {
                        voice.stopSpeaking()
                        if store.forgetLifeEvent(id: eventID, scope: scope) { event = nil; dismiss() }
                        else { error = "Your account or event changed." }
                    }
                } message: { Text("This removes the saved event from future recall. Original calendar entries and chat history are separate.") }
                .onAppear { reload() }
                .onDisappear { voice.stopSpeaking() }
                .onChange(of: selection) { _, _ in voice.stopSpeaking() }
                .onChange(of: auth.currentUser) { _, _ in voice.stopSpeaking(); reload() }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { voice.stopSpeaking() } else { reload() }
                }
        }.tint(Color(hex: "#315E73"))
    }
    private func reload() {
        event = store.accountScope == scope ? store.loadLifeEvents().first { $0.id == eventID } : nil
        if !cards.contains(where: { $0.id == selection }) { selection = "event" }
    }
    private func move(_ step: Int) {
        guard let index = cards.firstIndex(where: { $0.id == selection }), cards.indices.contains(index + step) else { return }
        selection = cards[index + step].id
    }
    private func toggle(_ section: String) {
        guard var updated = event else { return }
        voice.stopSpeaking()
        var hidden = Set(updated.hiddenReplaySections ?? [])
        if hidden.contains(section) { hidden.remove(section) } else { hidden.insert(section) }
        updated.hiddenReplaySections = hidden.sorted()
        if store.saveLifeEvent(updated, scope: scope, replacing: true) { event = updated; selection = "event"; error = nil }
        else { error = "Turn memory on and reopen this event to change its replay."; reload() }
    }
}

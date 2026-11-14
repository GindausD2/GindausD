import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ThoughtsView: View {
    @ObservedObject var store: ThoughtStore
    var scope: String?
    var canSync = true
    var prepareRecording: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var capture = ThoughtCapture()
    @State private var title = ""
    @State private var draftAudio: Data?
    @State private var showingEditor = false
    @State private var selectedID: UUID?
    @State private var alertKind: ThoughtAlertKind?
    @State private var message: String?
    @State private var recordingTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Space").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text("Thoughts").font(.headline).accessibilityAddTraits(.isHeader)
                Button {
                    title = ""
                    message = nil
                    draftAudio = nil
                    showingEditor = true
                } label: {
                    Label("Save a thought", systemImage: "mic")
                }
                .buttonStyle(.borderedProminent)
                ForEach(store.thoughts) { thought in
                    Button {
                        capture.stopPlayback()
                        selectedID = selectedID == thought.id ? nil : thought.id
                    } label: {
                        VStack(alignment: .leading) {
                            Text(thought.title).font(.headline)
                            Text("Saved from \(thought.source)").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    if selectedID == thought.id {
                        if let audio = thought.audio {
                            Button { capture.play(audio) } label: { Label("Play recording", systemImage: "play.circle") }
                        }
                        Button { alertKind = .reminder } label: { Label("Remind me", systemImage: "bell") }
                        #if os(iOS) && canImport(AlarmKit)
                        if #available(iOS 26.0, *), !ProcessInfo.processInfo.isiOSAppOnMac {
                            Button { alertKind = .alarm } label: { Label("Set alarm", systemImage: "alarm") }
                        }
                        #endif
                    }
                }
                if canSync {
                    Button(store.syncing ? "Syncing…" : "Sync with iCloud") {
                        if store.enableSync() { Task { await store.sync() } }
                    }
                    .disabled(store.syncing || scope == nil)
                    Text("Sync shares thoughts between Max apps signed into the same iCloud account.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let status = store.status { Text(status).font(.caption).foregroundStyle(.secondary) }
                if let message = message ?? capture.error { Text(message).font(.caption) }
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .task(id: scope) {
            store.open(scope: scope)
            selectedID = store.thoughts.first?.id
            if canSync && store.syncEnabled { await store.sync() }
        }
        .onChange(of: scope) { _, _ in
            showingEditor = false
            alertKind = nil
            discardCapture()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                recordingTask?.cancel()
                if capture.recording { draftAudio = capture.finish() }
                capture.stopPlayback()
            }
            if phase == .active, canSync && store.syncEnabled { Task { await store.sync() } }
        }
        .onDisappear { discardCapture() }
        .onChange(of: store.thoughts.map(\.id), initial: true) { _, ids in
            if selectedID == nil { selectedID = ids.first }
        }
        .sheet(isPresented: $showingEditor, onDismiss: discardCapture) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("New thought").font(.headline)
                    TextField("Title", text: $title)
                    if let error = capture.error ?? message { Text(error).font(.caption) }
                    if draftAudio != nil && !capture.recording {
                        Label("Recording ready to save", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    if capture.recording {
                        Button("Stop recording") { draftAudio = capture.finish() }
                    } else {
                        Button(draftAudio == nil ? "Record thought" : "Record again") {
                            prepareRecording()
                            recordingTask = Task {
                                await capture.start { draftAudio = capture.finish() }
                            }
                        }
                        .disabled(capture.starting)
                    }
                    Button("Save thought", action: save)
                        .disabled(scope == nil || capture.starting || capture.recording ||
                                  (draftAudio == nil && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    Button("Cancel", role: .cancel) { showingEditor = false }
                }
                .padding()
            }
        }
        .sheet(item: $alertKind) { kind in
            if let thought = store.thoughts.first(where: { $0.id == selectedID }) {
                ThoughtAlertView(thought: thought, kind: kind)
            }
        }
    }

    private func discardCapture() {
        recordingTask?.cancel()
        _ = capture.finish()
        capture.stopPlayback()
        draftAudio = nil
        capture.error = nil
    }

    private func save() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let thought = MaxThought(title: name.isEmpty ? "Voice thought" : String(name.prefix(160)),
                                 source: Self.device, audio: draftAudio)
        do {
            try store.save(thought)
            selectedID = thought.id
            message = nil
            showingEditor = false
            if canSync && store.syncEnabled { Task { await store.sync() } }
        } catch { message = "Max couldn’t save this thought." }
    }

    private static var device: String {
        #if os(watchOS)
        "Apple Watch"
        #elseif os(macOS)
        "Mac"
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #endif
    }
}

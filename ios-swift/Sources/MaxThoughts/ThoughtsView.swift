import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ThoughtsView: View {
    @ObservedObject var store: ThoughtStore
    var scope: String?
    var canSync = true
    var prepareRecording: () -> Void = {}
    @Binding var captureRequested: Bool
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var capture = ThoughtCapture()
    @State private var title = ""
    @State private var draftAudio: Data?
    @State private var draftTranscript = ""
    @State private var showingEditor = false
    @State private var selectedID: UUID?
    private struct AlertEditor: Identifiable {
        let thought: MaxThought
        let kind: ThoughtAlertKind
        var id: ThoughtAlertKind { kind }
    }
    @State private var alertEditor: AlertEditor?
    @State private var message: String?
    @State private var recordingTask: Task<Void, Never>?

    init(store: ThoughtStore, scope: String?, canSync: Bool = true,
         prepareRecording: @escaping () -> Void = {}, captureRequested: Binding<Bool> = .constant(false)) {
        self.store = store
        self.scope = scope
        self.canSync = canSync
        self.prepareRecording = prepareRecording
        _captureRequested = captureRequested
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Space").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text("Thoughts").font(.headline).accessibilityAddTraits(.isHeader)
                Button(action: openEditor) {
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
                        if let transcript = thought.transcript, !transcript.isEmpty {
                            #if os(watchOS)
                            Text(transcript)
                            #else
                            Text(transcript).textSelection(.enabled)
                            transcriptActions(transcript)
                            #endif
                        }
                        Button { alertEditor = AlertEditor(thought: thought, kind: .reminder) } label: {
                            Label(store.alert(for: thought.id, kind: .reminder) == nil ? "Remind me" : "Manage reminder", systemImage: "bell")
                        }
                        #if os(iOS) && canImport(AlarmKit)
                        if #available(iOS 26.0, *), !ProcessInfo.processInfo.isiOSAppOnMac {
                            Button { alertEditor = AlertEditor(thought: thought, kind: .alarm) } label: {
                                Label(store.alert(for: thought.id, kind: .alarm) == nil ? "Set alarm" : "Manage alarm", systemImage: "alarm")
                            }
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
        .onChange(of: captureRequested, initial: true) { _, requested in
            if requested {
                captureRequested = false
                openEditor()
            }
        }
        .task(id: scope) {
            store.open(scope: scope)
            selectedID = store.thoughts.first?.id
            if canSync && store.syncEnabled { await store.sync() }
        }
        .onChange(of: scope) { _, _ in
            showingEditor = false
            alertEditor = nil
            discardCapture()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                recordingTask?.cancel()
                if capture.recording { finishRecording() }
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
                        Label("Recording", systemImage: "record.circle.fill")
                            .foregroundStyle(.red)
                            .accessibilityAddTraits(.isHeader)
                        #if os(iOS)
                        ScrollViewReader { proxy in
                            ScrollView {
                                Text(capture.transcript.isEmpty ? "Your words will appear here." : capture.transcript)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Color.clear.frame(height: 1).id("transcript-end").accessibilityHidden(true)
                            }
                            .frame(minHeight: 56, maxHeight: 160)
                            .onChange(of: capture.transcript) { _, _ in proxy.scrollTo("transcript-end", anchor: .bottom) }
                        }
                        if !capture.transcript.isEmpty {
                            Button("Copy text", systemImage: "document.on.document") {
                                UIPasteboard.general.string = capture.transcript
                            }
                        }
                        #endif
                        Button("Stop recording", action: finishRecording)
                    } else {
                        Button(draftAudio == nil ? "Record thought" : "Record again") {
                            prepareRecording()
                            recordingTask = Task {
                                await capture.start { finishRecording() }
                            }
                        }
                        .disabled(capture.starting)
                    }
                    #if !os(watchOS)
                    if !capture.recording && !draftTranscript.isEmpty {
                        Text("Transcript").font(.headline)
                        TextEditor(text: $draftTranscript).frame(minHeight: 90)
                            .accessibilityLabel("Edit transcript")
                        transcriptActions(draftTranscript)
                    }
                    #endif
                    Button("Save thought", action: save)
                        .disabled(scope == nil || capture.starting || capture.recording ||
                                  (draftAudio == nil && draftTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                   title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    Button("Cancel", role: .cancel) { showingEditor = false }
                }
                .padding()
            }
        }
        .sheet(item: $alertEditor) { editor in
            if let scope {
                ThoughtAlertView(store: store, thought: editor.thought, kind: editor.kind, scope: scope)
            }
        }
    }

    private func finishRecording() {
        draftTranscript = capture.transcript
        draftAudio = capture.finish()
    }

    @ViewBuilder private func transcriptActions(_ text: String) -> some View {
        #if os(iOS)
        HStack {
            Button("Copy text", systemImage: "document.on.document") { UIPasteboard.general.string = text }
            ShareLink(item: text) { Label("Share text", systemImage: "square.and.arrow.up") }
        }
        #elseif os(macOS)
        ShareLink(item: text) { Label("Share text", systemImage: "square.and.arrow.up") }
        #endif
    }

    private func openEditor() {
        guard scope != nil, !showingEditor else { return }
        title = ""
        message = nil
        draftAudio = nil
        draftTranscript = ""
        showingEditor = true
    }

    private func discardCapture() {
        recordingTask?.cancel()
        _ = capture.finish()
        capture.stopPlayback()
        draftAudio = nil
        draftTranscript = ""
        capture.error = nil
    }

    private func save() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let transcript = draftTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let headline = name.isEmpty ? (transcript.components(separatedBy: .newlines).first ?? "") : name
        let thought = MaxThought(title: headline.isEmpty ? "Voice thought" : String(headline.prefix(160)),
                                 source: Self.device, audio: draftAudio, transcript: transcript.isEmpty ? nil : transcript)
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

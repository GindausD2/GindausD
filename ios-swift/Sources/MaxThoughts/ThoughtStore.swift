import CloudKit
import Combine
import Foundation

struct MaxThought: Codable, Identifiable {
    var id = UUID()
    var title: String
    var createdAt = Date()
    var source: String
    var audio: Data?
}

@MainActor
final class ThoughtStore: ObservableObject {
    static let shared = ThoughtStore()
    @Published private(set) var thoughts: [MaxThought] = []
    @Published private(set) var syncing = false
    @Published var status: String?
    private var local: [MaxThought] = []
    private var remote: [MaxThought] = []
    private var generation = UUID()
    private var scope: String?
    private var accountChanged: NSObjectProtocol?
    private let directory: URL

    init(directory: URL = URL.applicationSupportDirectory.appendingPathComponent("MaxThoughts", isDirectory: true)) {
        self.directory = directory
        accountChanged = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.discardRemote() }
        }
    }

    deinit {
        if let accountChanged { NotificationCenter.default.removeObserver(accountChanged) }
    }

    private var file: URL? {
        guard let scope else { return nil }
        return directory.appendingPathComponent(scope + ".json")
    }

    func removeLocal(scope: String) throws {
        if self.scope == scope {
            open(scope: nil)
        }
        for ext in ["json", "icloud", "sync"] {
            let url = directory.appendingPathComponent(scope).appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    func open(scope: String?) {
        guard self.scope != scope else { return }
        self.scope = scope
        local = []
        discardRemote()
        if let file, let data = try? Data(contentsOf: file) {
            do { local = try JSONDecoder().decode([MaxThought].self, from: data) }
            catch { status = "Saved thoughts could not be read." }
        }
        publish()
    }

    func save(_ thought: MaxThought) throws {
        guard let file else { throw CocoaError(.fileWriteNoPermission) }
        if local.isEmpty && FileManager.default.fileExists(atPath: file.path) {
            local = try JSONDecoder().decode([MaxThought].self, from: Data(contentsOf: file))
        }
        let updated = [thought] + local
        try write(updated, to: file)
        local = updated
        publish()
    }

    private func write(_ values: [MaxThought], to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: file, options: .atomic)
    }

    private func discardRemote() {
        generation = UUID()
        syncing = false
        status = nil
        remote = []
        publish()
    }

    private func publish() {
        let localIDs = Set(local.map(\.id))
        thoughts = (local + remote.filter { !localIDs.contains($0.id) }).sorted { $0.createdAt > $1.createdAt }
    }

    var syncEnabled: Bool {
        guard let file else { return false }
        return FileManager.default.fileExists(atPath: file.deletingPathExtension().appendingPathExtension("sync").path)
    }

    func enableSync() -> Bool {
        guard let file else { return false }
        let marker = file.deletingPathExtension().appendingPathExtension("sync")
        do {
            try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: marker, options: .atomic)
            return true
        } catch {
            status = "Max couldn’t save your sync preference."
            return false
        }
    }

    // Sync is an explicit action because iCloud is a separate account from Max sign-in.
    // Bind each local store to the first iCloud account used for sync.
    func sync() async {
        guard let file, let scope, syncEnabled, !syncing else { return }
        syncing = true
        status = nil
        let attempt = generation
        let container = CKContainer(identifier: "iCloud.com.gindausd.max")
        defer { if generation == attempt { syncing = false } }
        do {
            let owner = try await container.userRecordID().recordName
            guard generation == attempt else { return }
            let ownerFile = file.deletingPathExtension().appendingPathExtension("icloud")
            if FileManager.default.fileExists(atPath: ownerFile.path) {
                guard try String(contentsOf: ownerFile, encoding: .utf8) == owner else {
                    remote = []
                    publish()
                    status = "This device’s thoughts are linked to a different iCloud account."
                    return
                }
            } else {
                try FileManager.default.createDirectory(at: ownerFile.deletingLastPathComponent(), withIntermediateDirectories: true)
                try owner.write(to: ownerFile, atomically: true, encoding: .utf8)
            }
            let database = container.privateCloudDatabase
            if scope != "device" {
                let linkID = CKRecord.ID(recordName: "max-account-link")
                let link = CKRecord(recordType: "MaxThoughtAccount", recordID: linkID)
                link["scope"] = scope as CKRecordValue
                let existing: CKRecord
                do { existing = try await database.save(link) }
                catch let error as CKError where error.code == .serverRecordChanged {
                    existing = try await database.record(for: linkID)
                }
                guard generation == attempt else { return }
                guard existing["scope"] as? String == scope else {
                    status = "This iCloud inbox is already linked to another Max account."
                    return
                }
            }
            let snapshot = local
            for thought in snapshot {
                guard generation == attempt else { return }
                let record = CKRecord(recordType: "MaxThought", recordID: .init(recordName: thought.id.uuidString))
                record["payload"] = try JSONEncoder().encode(thought) as CKRecordValue
                do { _ = try await database.save(record) }
                catch let error as CKError where error.code == .serverRecordChanged { continue }
            }
            let query = CKQuery(recordType: "MaxThought", predicate: NSPredicate(value: true))
            var page = try await database.records(matching: query)
            var fetched: [MaxThought] = []
            while true {
                for (_, result) in page.matchResults {
                    let record = try result.get()
                    guard let data = record["payload"] as? Data else { continue }
                    fetched.append(try JSONDecoder().decode(MaxThought.self, from: data))
                }
                guard let cursor = page.queryCursor else { break }
                guard generation == attempt else { return }
                page = try await database.records(continuingMatchFrom: cursor)
            }
            guard generation == attempt else { return }
            remote = fetched
            publish()
            if Set(local.map(\.id)) == Set(snapshot.map(\.id)) {
                status = "Synced with iCloud"
            } else {
                syncing = false
                await sync()
            }
        } catch {
            guard generation == attempt else { return }
            status = "Couldn’t sync. Thoughts recorded on this device are still saved."
        }
    }
}

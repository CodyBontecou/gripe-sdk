#if canImport(UIKit)
import Foundation

struct QueuedReport: Codable {
    let endpoint: URL
    let apiKey: String
    let repository: String?
    let metadataJSON: Data
    let comment: String
    let pngData: Data
    let createdAt: Date

    init(
        endpoint: URL,
        apiKey: String,
        repository: String?,
        metadataJSON: Data,
        comment: String,
        pngData: Data,
        createdAt: Date = Date()
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.repository = repository
        self.metadataJSON = metadataJSON
        self.comment = comment
        self.pngData = pngData
        self.createdAt = createdAt
    }
}

final class RetryQueue {
    static let shared = RetryQueue()

    private let directory: URL
    private let maxItems = 25
    private let maxAge: TimeInterval = 7 * 24 * 60 * 60
    private let lock = NSLock()

    private init() {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.directory = base.appendingPathComponent("Gripe/queue", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func enqueue(_ report: QueuedReport) {
        lock.lock(); defer { lock.unlock() }
        do {
            let url = directory.appendingPathComponent("\(UUID().uuidString).json")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            try data.write(to: url, options: .atomic)
            evictIfNeeded()
        } catch {
            // Best-effort persistence; if we can't write, the report is simply lost.
        }
    }

    func flushInBackground() {
        Task.detached(priority: .background) { [weak self] in
            await self?.flush()
        }
    }

    private func flush() async {
        for entry in listEntries() {
            if expired(entry) {
                try? FileManager.default.removeItem(at: entry.url)
                continue
            }
            let result = await GripeAPIClient.shared.send(entry.report)
            switch result {
            case .success:
                try? FileManager.default.removeItem(at: entry.url)
            case .failure(let error):
                if let gripe = error as? GripeError {
                    if !gripe.isTransient {
                        try? FileManager.default.removeItem(at: entry.url)
                    }
                    if case .rateLimited = gripe {
                        return
                    }
                }
            }
        }
    }

    private func listEntries() -> [(url: URL, report: QueuedReport)] {
        lock.lock(); defer { lock.unlock() }
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries: [(URL, QueuedReport)] = urls.compactMap { url in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let report = try? decoder.decode(QueuedReport.self, from: data) else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            return (url, report)
        }
        return entries.sorted { $0.1.createdAt < $1.1.createdAt }
    }

    private func expired(_ entry: (url: URL, report: QueuedReport)) -> Bool {
        Date().timeIntervalSince(entry.report.createdAt) > maxAge
    }

    private func evictIfNeeded() {
        let entries = listEntries()
        guard entries.count > maxItems else { return }
        let extra = entries.count - maxItems
        for i in 0..<extra {
            try? FileManager.default.removeItem(at: entries[i].url)
        }
    }
}
#endif

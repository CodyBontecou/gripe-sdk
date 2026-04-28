#if canImport(UIKit) && DEBUG
import XCTest
@testable import GripeSDK

final class RetryQueueTests: XCTestCase {
    override func setUp() {
        super.setUp()
        RetryQueue.shared.purgeForTesting()
    }

    override func tearDown() {
        RetryQueue.shared.purgeForTesting()
        super.tearDown()
    }

    // Regression guard for the 0.2.1 → 0.2.2 fix:
    // listEntriesLocked() returns a labeled tuple `(url:, report:)`, but a
    // local annotation had stripped the labels and propagated the unlabeled
    // type to flush(), breaking compilation. The `.url` / `.report` accesses
    // below fail to compile if that regression returns.
    func testSnapshotExposesLabeledTuple() {
        let queue = RetryQueue.shared
        let report = makeReport(comment: "labels")
        queue.enqueue(report)

        let entries = queue.snapshotForTesting()
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertTrue(entry.url.lastPathComponent.hasSuffix(".json"))
        XCTAssertEqual(entry.report.comment, "labels")
        XCTAssertEqual(entry.report.apiKey, "k")
    }

    func testEnqueuePreservesAllFields() {
        let queue = RetryQueue.shared
        let endpoint = URL(string: "https://example.com/ingest")!
        let metadata = Data(#"{"a":1}"#.utf8)
        let png = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let original = QueuedReport(
            endpoint: endpoint,
            apiKey: "secret",
            repository: "owner/repo",
            metadataJSON: metadata,
            comment: "hello",
            pngData: png
        )
        queue.enqueue(original)

        let entries = queue.snapshotForTesting()
        XCTAssertEqual(entries.count, 1)
        let decoded = entries[0].report
        XCTAssertEqual(decoded.endpoint, endpoint)
        XCTAssertEqual(decoded.apiKey, "secret")
        XCTAssertEqual(decoded.repository, "owner/repo")
        XCTAssertEqual(decoded.metadataJSON, metadata)
        XCTAssertEqual(decoded.comment, "hello")
        XCTAssertEqual(decoded.pngData, png)
    }

    func testSnapshotSortedByCreatedAt() {
        let queue = RetryQueue.shared
        let older = makeReport(comment: "older", createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = makeReport(comment: "newer", createdAt: Date(timeIntervalSince1970: 2_000))
        queue.enqueue(newer)
        queue.enqueue(older)

        let entries = queue.snapshotForTesting()
        XCTAssertEqual(entries.map(\.report.comment), ["older", "newer"])
    }

    private func makeReport(
        comment: String,
        createdAt: Date = Date()
    ) -> QueuedReport {
        QueuedReport(
            endpoint: URL(string: "https://example.com")!,
            apiKey: "k",
            repository: nil,
            metadataJSON: Data("{}".utf8),
            comment: comment,
            pngData: Data([0x00]),
            createdAt: createdAt
        )
    }
}
#endif

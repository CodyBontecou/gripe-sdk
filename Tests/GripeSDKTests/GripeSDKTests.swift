import XCTest
@testable import GripeSDK

final class GripeSDKTests: XCTestCase {
    func testSharedInstanceExists() {
        _ = Gripe.shared
    }

    func testStartSetsConfiguration() {
        Gripe.start(apiKey: "test-key", dryRun: true)
        XCTAssertEqual(Gripe.shared.configuration?.apiKey, "test-key")
        XCTAssertTrue(Gripe.shared.configuration?.dryRun ?? false)
        Gripe.stop()
        XCTAssertNil(Gripe.shared.configuration)
    }
}

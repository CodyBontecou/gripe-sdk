#if canImport(UIKit)
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
        XCTAssertEqual(Gripe.shared.configuration?.environment, .debug)
        Gripe.stop()
        XCTAssertNil(Gripe.shared.configuration)
    }

    func testStartAcceptsEnvironmentAndInstaller() {
        Gripe.start(
            apiKey: "test-key",
            dryRun: true,
            environment: .staging,
            installer: "claude-code",
            telemetry: true
        )
        XCTAssertEqual(Gripe.shared.configuration?.environment, .staging)
        XCTAssertEqual(Gripe.shared.configuration?.installer, "claude-code")
        XCTAssertTrue(Gripe.shared.configuration?.telemetry ?? false)
        Gripe.stop()
    }
}
#endif

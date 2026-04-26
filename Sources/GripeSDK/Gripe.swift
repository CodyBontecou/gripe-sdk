import UIKit

public final class Gripe {
    public struct Configuration {
        public var apiKey: String
        public var endpoint: URL
        public var dryRun: Bool

        public init(apiKey: String, endpoint: URL, dryRun: Bool) {
            self.apiKey = apiKey
            self.endpoint = endpoint
            self.dryRun = dryRun
        }
    }

    public static let shared = Gripe()

    var configuration: Configuration?
    private let installer = GestureInstaller()
    private var inFlight = false

    private init() {}

    public static func start(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.gripe.dev/v1/reports")!,
        dryRun: Bool = false
    ) {
        shared.configuration = Configuration(apiKey: apiKey, endpoint: endpoint, dryRun: dryRun)
        shared.installer.install { [weak shared = shared] in
            shared?.handleTrigger()
        }
    }

    public static func stop() {
        shared.installer.uninstall()
        shared.configuration = nil
    }

    public static func trigger() {
        shared.handleTrigger()
    }

    private func handleTrigger() {
        guard !inFlight else { return }
        inFlight = true
        CaptureFlow.start { [weak self] in
            self?.inFlight = false
        }
    }
}

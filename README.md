# GripeSDK

**AI-installed in-app feedback for iOS.** Drop one line into your app — or ask your coding agent to do it for you — and a hidden 3-tap / 2-finger gesture opens a screenshot → crop → annotate → submit flow that files a GitHub issue automatically.

- **AI-native install** — say "add gripe to this app" to Claude Code, Cursor, Codex, or Windsurf.
- **One-call manual install** — `Gripe.start(apiKey: ...)` in your `App.init` or `AppDelegate`.
- **No UI changes required** — gesture is attached to every `UIWindow`. SwiftUI and UIKit both work.
- **Annotate before submitting** — crop, draw, type, tag.
- **Auto-collected metadata** — device, OS, app version, locale, view controller, timestamp.
- **Offline-safe** — failed submissions are persisted to disk and retried automatically on the next launch.
- **GitHub-backed** — reports land as issues in the repo of your choice.

## Requirements

- iOS 15+
- Swift 5.7+

## Install with an AI agent (recommended)

If you use a coding agent, the fastest path is to let it do the install. The repo ships a [Claude Code](https://docs.anthropic.com/claude-code) skill, plus parallel rules/workflows for Cursor, Codex CLI, and Windsurf — all driving the same shell scripts under `.claude/skills/gripe-sdk-integrate/scripts/`.

```bash
# One-time: clone the SDK so your agent can find the install bundle.
git clone https://github.com/CodyBontecou/gripe-sdk.git ~/src/gripe-sdk

# Claude Code
ln -s ~/src/gripe-sdk/.claude/skills/gripe-sdk-integrate ~/.claude/skills/gripe-sdk-integrate

# Cursor / Codex / Windsurf — see the matching rule files in this repo and copy alongside your project.
```

Then, in the iOS app you want to instrument, ask your agent:

> "Add gripe-sdk to this app."

The agent will detect your project, add the package dependency, and insert a `#if DEBUG`-gated `Gripe.start(...)` call into your entrypoint with `installer: "claude-code"` (or whichever agent it is) so installs are attributed.

See [`.claude/skills/gripe-sdk-integrate/`](./.claude/skills/gripe-sdk-integrate) for the full skill source and the manual scripts.

## Manual install (Swift Package Manager)

### Xcode

1. **File → Add Package Dependencies…**
2. Enter `https://github.com/CodyBontecou/gripe-sdk.git`.
3. Set the version rule to **Up to Next Major** from `0.2.0` (latest tagged release).
4. Add the `GripeSDK` library to your app target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/CodyBontecou/gripe-sdk.git", from: "0.2.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: ["GripeSDK"]
    ),
]
```

## Usage

### SwiftUI

```swift
import SwiftUI
import GripeSDK

@main
struct MyApp: App {
    init() {
        #if DEBUG
        Gripe.start(apiKey: "YOUR_API_KEY", environment: .debug)
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### UIKit

```swift
import UIKit
import GripeSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        Gripe.start(apiKey: "YOUR_API_KEY", environment: .debug)
        #endif
        return true
    }
}
```

Then **3-tap with 2 fingers** anywhere in the app to open the report flow.

## API surface

```swift
Gripe.start(
    apiKey: String,
    endpoint: URL = URL(string: "https://gripe.isolated.tech/v1/reports")!,
    dryRun: Bool = false,                           // backend echoes without filing an issue
    repository: String? = nil,                      // "owner/repo" override
    environment: Gripe.Environment = .debug,        // .debug / .staging / .production
    installer: String? = nil,                       // e.g. "claude-code", "cursor"; set by the install skill
    telemetry: Bool = true                          // when false, omits installer attribution from reports
)

// Open the capture flow programmatically (e.g. from a debug menu)
Gripe.trigger()

// Uninstall the gesture (e.g. when toggling off in settings)
Gripe.stop()
```

### `environment`

Tagged on every report so you can filter `.debug` noise from real beta/production feedback in the dashboard. Defaults to `.debug` because we recommend `#if DEBUG`-gating `Gripe.start` — flip to `.staging` or `.production` only when you've thought about the privacy implications of capturing screenshots from real users.

### `installer`

Free-form string the install skill stamps on reports. Useful for attribution ("how many of our users installed via Claude Code?"). Honored only when `telemetry: true`.

### `telemetry`

Controls whether the SDK attaches install-attribution metadata (`installer`, SDK version) to reports. Set to `false` to opt out — feedback reports themselves still go through; only the meta-fields about who installed the SDK are dropped.

## Recommended hygiene

### Gate behind `#if DEBUG`

Keep `Gripe.start` inside `#if DEBUG` so the gesture and code path don't ship to production users by default.

### Don't ship API keys in source

Use an `.xcconfig`, environment variable, or `Info.plist` build setting to inject the API key at build time. `"REPLACE_ME"` literals are fine for the first wire-up but should not be committed.

## What happens when submission fails

GripeSDK persists failed reports to `Application Support/Gripe/queue/` and retries them in the background on the next call to `Gripe.start`:

- **Network or server errors** → queued, retried silently next launch.
- **Rate-limited (`429`)** → queued, drained respecting `Retry-After`.
- **Unauthorized (`401`/`403`)** → not retried (treated as permanent until `Gripe.start` is called with a new key).
- **Encoding / invalid response errors** → not retried; surfaced to the user immediately.

The queue is capped at 25 items and 7 days; older entries are dropped quietly.

## License

The Swift SDK in this repository is released under the [MIT License](./LICENSE).

The hosted backend at `gripe.isolated.tech` is a closed-source SaaS. The SDK is free to use against any compatible backend; bring-your-own-server is supported (`Gripe.start(endpoint:)`).

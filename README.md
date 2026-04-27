# GripeSDK

In-app feedback for iOS apps. Drop one line into your app, and a hidden 3-tap / 2-finger gesture opens a screen-snapshot, crop, annotate, and submit flow that files a GitHub issue automatically.

- **One-call install** — `Gripe.start(apiKey: ...)` in your `App.init` or `AppDelegate`.
- **No UI changes required** — gesture is attached to every `UIWindow`. SwiftUI and UIKit both work.
- **Annotate before submitting** — crop, draw, type, tag.
- **Auto-collected metadata** — device, OS, app version, locale, timestamp.
- **GitHub-backed** — reports land as issues in the repo of your choice.

## Requirements

- iOS 15+
- Swift 5.7+

## Install

### Swift Package Manager (Xcode)

1. **File → Add Package Dependencies…**
2. Enter `https://github.com/CodyBontecou/gripe-sdk.git`.
3. Set the version rule to **Up to Next Major** from `0.1.0` (latest tagged release).
4. Add the `GripeSDK` library to your app target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/CodyBontecou/gripe-sdk.git", from: "0.1.0"),
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
        Gripe.start(apiKey: "YOUR_API_KEY")
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
        Gripe.start(apiKey: "YOUR_API_KEY")
        #endif
        return true
    }
}
```

Then **3-tap with 2 fingers** anywhere in the app to open the report flow.

### API surface

```swift
// Start (typically once at launch)
Gripe.start(
    apiKey: String,
    endpoint: URL = URL(string: "https://api.gripe.dev/v1/reports")!,
    dryRun: Bool = false,            // backend echoes without filing an issue
    repository: String? = nil        // "owner/repo" override
)

// Open the capture flow programmatically (e.g. from a debug menu)
Gripe.trigger()

// Uninstall the gesture (e.g. when toggling off in settings)
Gripe.stop()
```

### Recommended: gate behind `#if DEBUG`

Keep `Gripe.start` inside `#if DEBUG` so the gesture and code path don't ship to production users by default.

### Don't ship API keys in source

Use an `.xcconfig`, environment variable, or `Info.plist` build setting to inject the API key at build time. `"REPLACE_ME"` literals are fine for the first wire-up but should not be committed.

## Agent integration

This repo ships with a [Claude Code](https://docs.anthropic.com/claude-code) skill that automates SDK integration into another iOS app. The skill detects the target project, adds the package dependency, and inserts `Gripe.start(...)` into the right entrypoint.

Skill source: [`.claude/skills/gripe-sdk-integrate/`](./.claude/skills/gripe-sdk-integrate)

### Install the skill

```bash
git clone https://github.com/CodyBontecou/gripe-sdk.git ~/src/gripe-sdk

# Symlink so `git pull` keeps it current:
ln -s ~/src/gripe-sdk/.claude/skills/gripe-sdk-integrate ~/.claude/skills/gripe-sdk-integrate

# Or copy as a one-shot:
# cp -R ~/src/gripe-sdk/.claude/skills/gripe-sdk-integrate ~/.claude/skills/
```

Restart Claude Code so it indexes the new skill.

### Use it

Open Claude Code in **the iOS app** you want to add Gripe to, then either:

```
/gripe-sdk-integrate
```

…or just say "add gripe-sdk to this app" / "wire up gripe". The agent will:

1. Detect `.xcodeproj` / `.xcworkspace` / `Package.swift` and your `@main` entrypoint.
2. Confirm the target scheme and entrypoint with you.
3. Add the `GripeSDK` package dependency.
4. Insert `import GripeSDK` and a `#if DEBUG`-gated `Gripe.start(apiKey: "REPLACE_ME")` call.
5. Resolve packages and run a sanity build.

See [`.claude/skills/gripe-sdk-integrate/README.md`](./.claude/skills/gripe-sdk-integrate/README.md) for manual script usage and `--source local --local-path …` mode for SDK developers.

## License

TBD

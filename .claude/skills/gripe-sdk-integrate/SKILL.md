---
name: gripe-sdk-integrate
description: Integrate the GripeSDK in-app feedback library into an iOS app. Adds the Swift package dependency, imports it in the app entrypoint, and inserts the Gripe.start(...) launch call so a 3-tap-2-finger gesture opens the bug-report capture flow. Use when the user says "add gripe", "integrate gripe-sdk", "wire up gripe", or asks to drop the bug-reporting SDK into an iOS project.
---

# Gripe SDK Integration

Add the `GripeSDK` Swift package to an iOS app and wire it into the app entrypoint so users can file annotated bug reports via a 3-tap / 2-finger gesture.

SDK repo: `https://github.com/CodyBontecou/gripe-sdk.git`

When this skill ships from the SDK repo it lives at `.claude/skills/gripe-sdk-integrate/`. When installed for global use the canonical location is `~/.claude/skills/gripe-sdk-integrate/`. All script paths below are relative to the directory containing this SKILL.md, so resolve `SKILL_DIR` once and reuse it:

```bash
SKILL_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "<this SKILL.md location>")")"
# In practice: pass the directory containing this SKILL.md as $SKILL_DIR.
```

## What you're adding

A single launch-time call:

```swift
import GripeSDK
// ...
Gripe.start(apiKey: "<API_KEY>")
```

`Gripe.start` installs a hidden gesture (3 taps with 2 fingers) on every `UIWindow`. When triggered it snapshots the screen and presents the crop / annotate / submit flow. The SDK supports iOS 15+ and is UIKit-based but works inside SwiftUI apps because they sit on top of `UIWindow`.

Optional parameters on `Gripe.start`:
- `endpoint: URL` — backend (default `https://gripe.isolated.tech/v1/reports`)
- `dryRun: Bool` — when `true`, the backend echoes back without filing a GitHub issue
- `repository: String?` — `"owner/repo"` to override server default
- `environment: Gripe.Environment` — `.debug` (default), `.staging`, or `.production`. Tagged on every report so you can filter `.debug` noise from real users in the dashboard.
- `installer: String?` — installer attribution. **When this skill inserts the call, always set `installer: "claude-code"`** so installs done via Claude Code are visible in the dashboard. Other agent-specific copies of this skill set their own value (`"cursor"`, `"codex"`, `"windsurf"`).
- `telemetry: Bool` — defaults to `true`. When `false`, the SDK omits installer attribution from reports. Honor user requests to set this to `false`.

`Gripe.stop()` uninstalls the gesture. `Gripe.trigger()` opens the flow programmatically.

## Workflow

### Step 1 — Detect the target project

Run from the iOS app's repo root (or pass a directory):

```bash
bash "$SKILL_DIR/scripts/detect-project.sh" [start_dir]
```

The script prints key=value lines you can read directly:

- `KIND=xcodeproj|workspace|spm` — what kind of project this is
- `PROJECT=<absolute path>` — the `.xcodeproj`, `.xcworkspace`, or `Package.swift`
- `APP_TARGET=<scheme name>` — best-guess app target (first non-test target)
- `ENTRYPOINT=<absolute path>` — file containing `@main` (SwiftUI `App` struct) or `@UIApplicationMain` / `AppDelegate`
- `ENTRYPOINT_KIND=swiftui|appdelegate|unknown`
- `MIN_IOS=<version>` — first deployment target found, for sanity-checking against iOS 15

If `MIN_IOS` is below `15.0`, stop and tell the user GripeSDK requires iOS 15+; ask whether to bump the deployment target.

### Step 2 — Confirm with the user before changing anything

Before writing changes, confirm:
- The detected `APP_TARGET` (the scheme that will get the dependency)
- The `ENTRYPOINT` file you'll edit
- Whether to use the **git URL** (default, recommended) or a **local path** to a checkout of `gripe-sdk` (useful for SDK development — pass `--local-path /path/to/gripe-sdk`)
- The API key to insert. If the user doesn't have one, insert the placeholder `"REPLACE_ME"` and tell them where to swap it.

Default to git URL + `from: "0.2.0"` unless the user asks for `branch: "main"` or local path.

### Step 3 — Add the package dependency

#### 3a. SPM-based app (`Package.swift` exists, no `.xcodeproj`)

```bash
bash "$SKILL_DIR/scripts/add-package-spm.sh" \
  --package <path/to/Package.swift> \
  --target <APP_TARGET> \
  --source git
# Or, for SDK developers iterating locally:
#   --source local --local-path /path/to/gripe-sdk
```

This edits `Package.swift` to add a `.package(url: ..., from: "0.1.0")` (or `.package(path: ...)`) entry and adds `"GripeSDK"` to the named target's `dependencies`.

#### 3b. Xcode project (`.xcodeproj` or `.xcworkspace`)

```bash
ruby "$SKILL_DIR/scripts/add-package-xcodeproj.rb" \
  --project <path/to/App.xcodeproj> \
  --target <APP_TARGET> \
  --source git
# Or:
#   --source local --local-path /path/to/gripe-sdk
```

This uses the `xcodeproj` Ruby gem to add the Swift package reference and link `GripeSDK` to the target. The script will `gem install xcodeproj` (user scope) on first run if the gem is missing.

For workspaces, pass the inner `.xcodeproj` that contains the app target — the `xcodeproj` gem does not edit workspaces directly.

### Step 4 — Inject `Gripe.start(...)` into the app entrypoint

Use **Edit**, not a script — this requires understanding the file structure. Open `ENTRYPOINT` and:

#### SwiftUI app (`ENTRYPOINT_KIND=swiftui`)

Find the `@main struct ... : App` and add an `init()` that calls `Gripe.start`. Add `import GripeSDK` near the top.

```swift
import SwiftUI
import GripeSDK

@main
struct MyApp: App {
    init() {
        #if DEBUG
        Gripe.start(
            apiKey: "REPLACE_ME",
            environment: .debug,
            installer: "claude-code"
        )
        #endif
    }
    var body: some Scene { /* ... */ }
}
```

If an `init()` already exists, add the `Gripe.start` call inside it, after any existing setup. Don't overwrite existing init body.

#### UIKit AppDelegate (`ENTRYPOINT_KIND=appdelegate`)

Insert into `application(_:didFinishLaunchingWithOptions:)` before the `return true`. Add `import GripeSDK` near the top.

```swift
import UIKit
import GripeSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        Gripe.start(
            apiKey: "REPLACE_ME",
            environment: .debug,
            installer: "claude-code"
        )
        #endif
        return true
    }
}
```

#### Unknown entrypoint

Stop and ask the user where they want the call. Don't guess.

### Step 5 — Resolve & build

After editing, resolve packages and build to verify:

```bash
# SPM app
swift build --package-path <package_dir>

# Xcode project — build for an arbitrary simulator
xcodebuild -project <App.xcodeproj> -scheme <APP_TARGET> \
  -destination 'generic/platform=iOS Simulator' \
  -resolvePackageDependencies
xcodebuild -project <App.xcodeproj> -scheme <APP_TARGET> \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

If the build fails on `import GripeSDK`, check that the package was linked to the target (Xcode: target → Frameworks, Libraries, and Embedded Content).

### Step 6 — Tell the user how to test

Print a short summary:

1. Replace `"REPLACE_ME"` in `<ENTRYPOINT>` with the real API key from the Gripe dashboard (or set `dryRun: true` to test without filing issues).
2. Run on a device or simulator. Tap with **two fingers, three times** anywhere in the app to open the report flow.
3. To trigger programmatically (e.g. from a debug menu), call `Gripe.trigger()`.
4. To disable in production, the `#if DEBUG` block already gates this — leave as-is.

## Notes

- Do not embed the API key as a string literal in shipping builds. Recommend `Info.plist` + xcconfig, or an env-driven build setting. For initial wiring just use the placeholder.
- The SDK is UIKit-only behind `#if canImport(UIKit)`, so no extra work is needed for SwiftUI apps — the `import GripeSDK` and `Gripe.start` calls are the entirety of integration.
- If the user is on iOS 14 or below, GripeSDK will not compile. Either bump the deployment target to 15.0 or refuse and explain.

---
description: Integrate the GripeSDK in-app feedback library into this iOS app.
auto_execution_mode: 1
---

# GripeSDK installer (Windsurf)

When the user says "add gripe", "integrate gripe-sdk", "wire up gripe", or similar, run this workflow. **Always set `installer: "windsurf"`** in the inserted `Gripe.start(...)` call so the install is attributed correctly in the gripe.isolated.tech dashboard.

## 1. Prerequisite

The install scripts live in the cloned `gripe-sdk` repo. Default path:

```bash
SKILL_DIR="$HOME/src/gripe-sdk/.claude/skills/gripe-sdk-integrate"
[ -d "$HOME/src/gripe-sdk" ] || git clone https://github.com/CodyBontecou/gripe-sdk.git "$HOME/src/gripe-sdk"
```

If the user cloned elsewhere, ask once and reuse that path.

## 2. Detect the project

```bash
bash "$SKILL_DIR/scripts/detect-project.sh" .
```

Parse the `KEY=VALUE` output: `KIND`, `PROJECT`, `APP_TARGET`, `ENTRYPOINT`, `ENTRYPOINT_KIND`, `MIN_IOS`. If `MIN_IOS` < `15.0`, stop and confirm before bumping.

## 3. Confirm with the user

Show the detected `APP_TARGET` and `ENTRYPOINT`. Ask for the API key or use `"REPLACE_ME"`.

## 4. Add the package

```bash
# SPM apps
bash "$SKILL_DIR/scripts/add-package-spm.sh" --package <Package.swift> --target <APP_TARGET> --source git

# Xcode projects
ruby "$SKILL_DIR/scripts/add-package-xcodeproj.rb" --project <App.xcodeproj> --target <APP_TARGET> --source git
```

## 5. Inject `Gripe.start(...)` into the entrypoint

Edit the entrypoint file directly. **Don't shell out for this** — Windsurf's editor handles Swift better.

SwiftUI (`@main struct ... : App`):

```swift
import GripeSDK

init() {
    #if DEBUG
    Gripe.start(
        apiKey: "REPLACE_ME",
        environment: .debug,
        installer: "windsurf"
    )
    #endif
}
```

UIKit `AppDelegate`:

```swift
import GripeSDK

#if DEBUG
Gripe.start(
    apiKey: "REPLACE_ME",
    environment: .debug,
    installer: "windsurf"
)
#endif
```

If `init()` already exists in the SwiftUI app, append to it — don't overwrite.

## 6. Build to verify

```bash
# SPM
swift build --package-path <package_dir>

# Xcode
xcodebuild -project <App.xcodeproj> -scheme <APP_TARGET> \
  -destination 'generic/platform=iOS Simulator' \
  -resolvePackageDependencies
xcodebuild -project <App.xcodeproj> -scheme <APP_TARGET> \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

## 7. Tell the user how to test

2-finger 3-tap anywhere in the app to open the report flow. Replace `"REPLACE_ME"` with a real API key from gripe.isolated.tech, or set `dryRun: true` for offline testing.

## Hygiene

- Don't ship API keys as string literals — recommend `.xcconfig` / `Info.plist` injection.
- Keep `Gripe.start` inside the `#if DEBUG` block unless the user explicitly opts in.
- Honor `telemetry: false` if the user opts out of install attribution.

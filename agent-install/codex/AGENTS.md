# GripeSDK installer (Codex CLI)

> If you already have an `AGENTS.md` in this repo, paste this section into it under `## Tasks` or a similar heading.

## Task: integrate GripeSDK

When the user asks to "add gripe", "integrate gripe-sdk", "wire up gripe", or similar, perform the steps below. **Always set `installer: "codex"`** in the inserted `Gripe.start(...)` call so the install is attributed correctly in the gripe.isolated.tech dashboard.

### Prerequisite

The install scripts live in the cloned `gripe-sdk` repo. Default path:

```bash
SKILL_DIR="$HOME/src/gripe-sdk/.claude/skills/gripe-sdk-integrate"
[ -d "$HOME/src/gripe-sdk" ] || git clone https://github.com/CodyBontecou/gripe-sdk.git "$HOME/src/gripe-sdk"
```

If the user cloned elsewhere, ask once and reuse that path.

### Steps

1. **Detect**:
   ```bash
   bash "$SKILL_DIR/scripts/detect-project.sh" .
   ```
   Parse `KIND`, `PROJECT`, `APP_TARGET`, `ENTRYPOINT`, `ENTRYPOINT_KIND`, `MIN_IOS`. If `MIN_IOS` < `15.0`, stop and ask before bumping.

2. **Confirm**: show the detected scheme/entrypoint to the user. Ask for:
   - The API key (or use `"REPLACE_ME"`).
   - **The destination GitHub repo** (`owner/repo`). **Required** for the hosted backend — without it every submit returns `400 repository_required`. Default to the same repo the app source lives in if the user is unsure.

3. **Add the package**:
   ```bash
   # SPM
   bash "$SKILL_DIR/scripts/add-package-spm.sh" --package <Package.swift> --target <APP_TARGET> --source git
   # Xcode
   ruby "$SKILL_DIR/scripts/add-package-xcodeproj.rb" --project <App.xcodeproj> --target <APP_TARGET> --source git
   ```

4. **Inject the launch call**. Edit the entrypoint file directly:

   - SwiftUI:
     ```swift
     import GripeSDK
     // inside @main struct App:
     init() {
         #if DEBUG
         Gripe.start(
             apiKey: "REPLACE_ME",
             repository: "OWNER/REPO",
             environment: .debug,
             installer: "codex"
         )
         #endif
     }
     ```

   - UIKit AppDelegate:
     ```swift
     import GripeSDK
     // inside application(_:didFinishLaunchingWithOptions:):
     #if DEBUG
     Gripe.start(
         apiKey: "REPLACE_ME",
         repository: "OWNER/REPO",
         environment: .debug,
         installer: "codex"
     )
     #endif
     ```

   Substitute `"OWNER/REPO"` with the value confirmed in step 2. Don't overwrite an existing `init()` body — append to it.

5. **Build to verify**:
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

6. **Tell the user**: 2-finger 3-tap anywhere to open the capture flow. Replace `"REPLACE_ME"` with the real key, or set `dryRun: true` for offline testing.

### Hygiene

- Don't ship API keys as string literals — recommend `.xcconfig`/`Info.plist` injection.
- Keep `Gripe.start` inside the `#if DEBUG` block unless the user explicitly removes it.
- Honor `telemetry: false` if the user opts out of install attribution.

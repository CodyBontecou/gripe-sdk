# gripe-sdk-integrate

A Claude Code skill that drops the [GripeSDK](https://github.com/CodyBontecou/gripe-sdk) in-app feedback library into another iOS app: adds the Swift Package dependency, links it to the app target, and inserts the launch-time `Gripe.start(...)` call.

## What it does

1. Detects the project (`.xcworkspace`, `.xcodeproj`, or `Package.swift`) and the app's `@main` entrypoint.
2. Adds the `GripeSDK` Swift package — by default from the GitHub URL, optionally as a local path with `--local-path`.
3. Inserts `import GripeSDK` and a `#if DEBUG`-gated `Gripe.start(apiKey:)` call into the app entrypoint.
4. Resolves packages and runs a sanity build.

After integration, a 3-tap / 2-finger gesture anywhere in the app opens the bug-report capture flow.

## Install

This skill ships in the SDK repo at `.claude/skills/gripe-sdk-integrate/`. To make it available in any iOS project:

```bash
# Option A: clone the SDK and symlink (auto-updates with `git pull`)
git clone https://github.com/CodyBontecou/gripe-sdk.git ~/src/gripe-sdk
ln -s ~/src/gripe-sdk/.claude/skills/gripe-sdk-integrate ~/.claude/skills/gripe-sdk-integrate

# Option B: copy as a one-shot
cp -R ~/src/gripe-sdk/.claude/skills/gripe-sdk-integrate ~/.claude/skills/
```

Restart Claude Code (or open a new session) so the skill index picks it up. From inside any iOS app, invoke it:

```
/gripe-sdk-integrate
```

…or just say "add gripe-sdk to this app" / "wire up gripe".

## Manual usage

```bash
SKILL=~/.claude/skills/gripe-sdk-integrate

# 1. Detect
bash "$SKILL/scripts/detect-project.sh" /path/to/ios-app

# 2a. Add to a Package.swift app
bash "$SKILL/scripts/add-package-spm.sh" \
  --package /path/to/Package.swift --target MyApp --source git

# 2b. Add to an .xcodeproj
ruby "$SKILL/scripts/add-package-xcodeproj.rb" \
  --project /path/to/App.xcodeproj --target MyApp --source git
```

`--source local --local-path /path/to/gripe-sdk` swaps the GitHub URL for a local checkout — useful when iterating on the SDK itself.

## Requirements

- iOS 15+ deployment target
- Xcode command line tools
- Ruby (system Ruby is fine — the script `gem install --user-install`s `xcodeproj` on first run)
- `python3` (for the `Package.swift` edit and Xcode `-list` parsing)

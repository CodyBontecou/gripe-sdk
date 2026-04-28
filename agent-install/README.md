# Agent install bundles

Drop-in install rules/workflows for AI coding agents other than Claude Code. Each one drives the same shell + Ruby scripts under [`../.claude/skills/gripe-sdk-integrate/scripts/`](../.claude/skills/gripe-sdk-integrate/scripts) and injects a `Gripe.start(...)` call into the host app's entrypoint, tagging it with the right `installer:` value so installs done by different agents are attributable in the dashboard.

| Agent      | File to copy                                                  | Destination in host app       |
|------------|---------------------------------------------------------------|-------------------------------|
| Cursor     | [`cursor/gripe-sdk-integrate.mdc`](./cursor/gripe-sdk-integrate.mdc) | `.cursor/rules/`              |
| Codex CLI  | [`codex/AGENTS.md`](./codex/AGENTS.md)                        | repo root (merge if existing) |
| Windsurf   | [`windsurf/gripe-sdk-integrate.md`](./windsurf/gripe-sdk-integrate.md) | `.windsurf/workflows/`        |

## Prerequisite

All agents expect `gripe-sdk` to be cloned somewhere on disk so they can call the install scripts. Default location:

```bash
git clone https://github.com/CodyBontecou/gripe-sdk.git ~/src/gripe-sdk
```

The rule files reference `$HOME/src/gripe-sdk/.claude/skills/gripe-sdk-integrate/scripts/` — adjust the path inside the file if you cloned elsewhere.

## How to invoke

After copying the rule file into the host app, ask your agent:

> "Add gripe-sdk to this app."

The agent will:

1. Run `detect-project.sh` to identify the project.
2. Add the package dependency via `add-package-spm.sh` or `add-package-xcodeproj.rb`.
3. Insert a `#if DEBUG`-gated `Gripe.start(apiKey: "REPLACE_ME", environment: .debug, installer: "<agent>")` call.
4. Build to verify.

Tell the agent to set `installer:` to its own name (`"cursor"`, `"codex"`, `"windsurf"`) — the rule file already calls this out.

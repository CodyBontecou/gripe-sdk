#!/usr/bin/env bash
# Detect an iOS project's structure for GripeSDK integration.
# Outputs key=value lines on stdout. Errors go to stderr; exits non-zero on hard failure.

set -euo pipefail

START="${1:-$PWD}"
START="$(cd "$START" && pwd)"

KIND=""
PROJECT=""
APP_TARGET=""
ENTRYPOINT=""
ENTRYPOINT_KIND="unknown"
MIN_IOS=""

# 1) Locate the project artifact.
# Preference: .xcworkspace > .xcodeproj > Package.swift.
WORKSPACE="$(/usr/bin/find "$START" -maxdepth 3 -type d -name '*.xcworkspace' \
  -not -path '*/.build/*' -not -path '*/Pods/*' -not -path '*/.swiftpm/*' \
  -not -path '*/xcuserdata/*' 2>/dev/null | head -n 1 || true)"
XCODEPROJ="$(/usr/bin/find "$START" -maxdepth 3 -type d -name '*.xcodeproj' \
  -not -path '*/.build/*' -not -path '*/Pods/*' -not -path '*/.swiftpm/*' \
  2>/dev/null | head -n 1 || true)"
PKG="$(/usr/bin/find "$START" -maxdepth 3 -type f -name 'Package.swift' \
  -not -path '*/.build/*' 2>/dev/null | head -n 1 || true)"

if [[ -n "$WORKSPACE" ]]; then
  KIND="workspace"
  PROJECT="$WORKSPACE"
elif [[ -n "$XCODEPROJ" ]]; then
  KIND="xcodeproj"
  PROJECT="$XCODEPROJ"
elif [[ -n "$PKG" ]]; then
  KIND="spm"
  PROJECT="$PKG"
else
  echo "ERROR: no .xcworkspace, .xcodeproj, or Package.swift found under $START" >&2
  exit 1
fi

# 2) Determine app target / scheme.
if [[ "$KIND" == "spm" ]]; then
  # First .target() name in Package.swift, ignoring testTargets.
  APP_TARGET="$(python3 - "$PROJECT" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
# Strip .testTarget(...) blocks.
text = re.sub(r"\.testTarget\s*\([^)]*\)", "", text, flags=re.S)
m = re.search(r"\.(?:executableTarget|target)\s*\(\s*name:\s*\"([^\"]+)\"", text)
print(m.group(1) if m else "")
PY
)"
elif [[ "$KIND" == "xcodeproj" ]]; then
  APP_TARGET="$(xcodebuild -project "$PROJECT" -list 2>/dev/null \
    | python3 -c '
import sys, re
section = None
for line in sys.stdin:
    line = line.rstrip()
    if re.match(r"^\s*Targets:\s*$", line):           section = "t"; continue
    if re.match(r"^\s*Build Configurations:\s*$", line): section = None; continue
    if re.match(r"^\s*Schemes:\s*$", line):              section = None; continue
    if section == "t":
        s = line.strip()
        if s and not re.search(r"Tests?$", s):
            print(s); sys.exit(0)
' || true)"
elif [[ "$KIND" == "workspace" ]]; then
  APP_TARGET="$(xcodebuild -workspace "$PROJECT" -list 2>/dev/null \
    | python3 -c '
import sys, re
section = None
for line in sys.stdin:
    line = line.rstrip()
    if re.match(r"^\s*Schemes:\s*$", line): section = "s"; continue
    if section == "s":
        s = line.strip()
        if s and not re.search(r"Tests?$", s):
            print(s); sys.exit(0)
' || true)"
fi

# 3) Find @main entrypoint file.
# Try SwiftUI App struct first, then UIKit AppDelegate.
SEARCH_ROOT="$START"
ENTRY_SWIFTUI="$(/usr/bin/grep -RIl --include='*.swift' \
  -E '^[[:space:]]*@main' "$SEARCH_ROOT" 2>/dev/null \
  --exclude-dir='.build' --exclude-dir='Pods' --exclude-dir='.swiftpm' \
  --exclude-dir='DerivedData' --exclude-dir='node_modules' \
  | /usr/bin/xargs -I{} /usr/bin/grep -l -E ':[[:space:]]*App[[:space:]]*\{' {} 2>/dev/null \
  | head -n 1 || true)"

if [[ -n "$ENTRY_SWIFTUI" ]]; then
  ENTRYPOINT="$ENTRY_SWIFTUI"
  ENTRYPOINT_KIND="swiftui"
else
  ENTRY_APPDELEGATE="$(/usr/bin/grep -RIl --include='*.swift' \
    -E 'class[[:space:]]+\w*AppDelegate|UIApplicationDelegate' "$SEARCH_ROOT" 2>/dev/null \
    --exclude-dir='.build' --exclude-dir='Pods' --exclude-dir='.swiftpm' \
    --exclude-dir='DerivedData' --exclude-dir='node_modules' \
    | head -n 1 || true)"
  if [[ -n "$ENTRY_APPDELEGATE" ]]; then
    ENTRYPOINT="$ENTRY_APPDELEGATE"
    ENTRYPOINT_KIND="appdelegate"
  fi
fi

# 4) Deployment target (best-effort).
if [[ "$KIND" == "xcodeproj" ]]; then
  MIN_IOS="$(/usr/bin/grep -h 'IPHONEOS_DEPLOYMENT_TARGET' "$PROJECT/project.pbxproj" 2>/dev/null \
    | /usr/bin/sed -E 's/.*= ([0-9]+\.[0-9]+).*/\1/' | sort -u | head -n 1 || true)"
elif [[ "$KIND" == "spm" ]]; then
  MIN_IOS="$(/usr/bin/grep -E '\.iOS\(\.v[0-9]+' "$PROJECT" \
    | /usr/bin/sed -E 's/.*\.v([0-9]+).*/\1/' | head -n 1 || true)"
fi

cat <<EOF
KIND=$KIND
PROJECT=$PROJECT
APP_TARGET=$APP_TARGET
ENTRYPOINT=$ENTRYPOINT
ENTRYPOINT_KIND=$ENTRYPOINT_KIND
MIN_IOS=$MIN_IOS
EOF

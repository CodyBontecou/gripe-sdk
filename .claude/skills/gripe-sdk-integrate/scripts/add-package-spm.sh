#!/usr/bin/env bash
# Add GripeSDK as a dependency in a Package.swift-based app.
# Usage:
#   add-package-spm.sh --package <Package.swift> --target <name> \
#                      --source git|local [--local-path <path>]

set -euo pipefail

GIT_URL="https://github.com/CodyBontecou/gripe-sdk.git"
VERSION="0.2.0"

PKG=""
TARGET=""
SOURCE="git"
LOCAL_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package)    PKG="$2"; shift 2 ;;
    --target)     TARGET="$2"; shift 2 ;;
    --source)     SOURCE="$2"; shift 2 ;;
    --local-path) LOCAL_PATH="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PKG" || -z "$TARGET" ]]; then
  echo "ERROR: --package and --target are required" >&2
  exit 2
fi
if [[ ! -f "$PKG" ]]; then
  echo "ERROR: Package.swift not found at $PKG" >&2
  exit 2
fi

if [[ "$SOURCE" == "git" ]]; then
  DEP_LINE=".package(url: \"$GIT_URL\", from: \"$VERSION\"),"
elif [[ "$SOURCE" == "local" ]]; then
  if [[ -z "$LOCAL_PATH" ]]; then
    echo "ERROR: --source local requires --local-path <path-to-gripe-sdk>" >&2
    exit 2
  fi
  if [[ ! -d "$LOCAL_PATH" ]]; then
    echo "ERROR: --local-path '$LOCAL_PATH' is not a directory" >&2
    exit 2
  fi
  DEP_LINE=".package(path: \"$LOCAL_PATH\"),"
else
  echo "ERROR: --source must be git or local" >&2
  exit 2
fi

cp "$PKG" "$PKG.bak"

if /usr/bin/grep -q "GripeSDK" "$PKG"; then
  echo "GripeSDK already referenced in $PKG; skipping" >&2
  exit 0
fi

# Insert dependency into the package-level dependencies: [...] array,
# and add "GripeSDK" to the named target's dependencies array.
python3 - "$PKG" "$DEP_LINE" "$TARGET" <<'PY'
import re, sys, pathlib

path = pathlib.Path(sys.argv[1])
dep_line = sys.argv[2]
target = sys.argv[3]
src = path.read_text()

def insert_into_first_array(text: str, key: str, line: str) -> str:
    pat = re.compile(r"(" + re.escape(key) + r"\s*:\s*\[)([^\]]*)(\])", re.S)
    m = pat.search(text)
    if not m:
        return text
    head, body, tail = m.group(1), m.group(2), m.group(3)
    body_stripped = body.strip()
    if "GripeSDK" in body_stripped or "gripe-sdk" in body_stripped:
        return text
    if not body_stripped:
        new_body = f"\n        {line}\n    "
    else:
        trimmed = body.rstrip()
        if not trimmed.endswith(","):
            trimmed = trimmed + ","
        new_body = trimmed + f"\n        {line}\n    "
    return text[:m.start()] + head + new_body + tail + text[m.end():]

src = insert_into_first_array(src, "dependencies", dep_line)

target_block_re = re.compile(
    r"\.(executableTarget|target)\s*\(\s*name:\s*\"" + re.escape(target) + r"\"(.*?)\)",
    re.S,
)
m = target_block_re.search(src)
if m:
    block = m.group(0)
    if "dependencies" in block:
        new_block = re.sub(
            r"(dependencies\s*:\s*\[)([^\]]*)(\])",
            lambda mm: (
                mm.group(0) if "GripeSDK" in mm.group(2) else
                mm.group(1)
                + (mm.group(2).rstrip().rstrip(",") + ", " if mm.group(2).strip() else "")
                + "\"GripeSDK\""
                + mm.group(3)
            ),
            block,
            count=1,
        )
    else:
        new_block = re.sub(
            r"(name:\s*\"" + re.escape(target) + r"\")",
            r'\1, dependencies: ["GripeSDK"]',
            block,
            count=1,
        )
    src = src[:m.start()] + new_block + src[m.end():]

path.write_text(src)
PY

echo "Updated $PKG (backup at $PKG.bak)"

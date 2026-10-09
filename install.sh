#!/bin/bash
# Installs the latest Drift release into /Applications.
#   curl -fsSL https://raw.githubusercontent.com/manu-tech-code/drift-releases/main/install.sh | bash
set -euo pipefail

REPO="manu-tech-code/drift-releases"
API="https://api.github.com/repos/$REPO"

WORK="$(mktemp -d)"; MOUNT="$WORK/mnt"
cleanup() { hdiutil detach -quiet "$MOUNT" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

echo "Finding the latest Drift…"
REL="$(curl -fsSL -H "Accept: application/vnd.github+json" "$API/releases/latest")"
read -r VERSION DMG_URL < <(python3 -c '
import json,sys
r=json.load(sys.stdin)
a=[x for x in r["assets"] if x["name"].endswith(".dmg")][0]
print(r["tag_name"].lstrip("v"), a["browser_download_url"])' <<<"$REL")

echo "Downloading Drift $VERSION…"
curl -fsSL -o "$WORK/Drift.dmg" "$DMG_URL"

mkdir "$MOUNT"
hdiutil attach -nobrowse -quiet -mountpoint "$MOUNT" "$WORK/Drift.dmg"
codesign --verify --deep --strict "$MOUNT/Drift.app"

if pgrep -f /Applications/Drift.app/Contents/MacOS/Drift >/dev/null; then
  osascript -e 'tell application "Drift" to quit' || true
  for _ in $(seq 1 20); do pgrep -f /Applications/Drift.app/Contents/MacOS/Drift >/dev/null || break; sleep 1; done
fi

rm -rf /Applications/Drift.app
ditto "$MOUNT/Drift.app" /Applications/Drift.app
xattr -dr com.apple.quarantine /Applications/Drift.app 2>/dev/null || true
echo "Installed Drift $VERSION in /Applications."
open /Applications/Drift.app

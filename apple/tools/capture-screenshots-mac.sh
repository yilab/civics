#!/bin/bash
# Captures Mac App Store screenshots (English + zh-Hans UI) of the macOS build
# and saves them under <out>/en and <out>/zh-Hans at 2560x1600 px.
#
#   apple/tools/capture-screenshots-mac.sh assets/screenshots/apple/mac
#
# Builds the app and launches it with -renderScreenshots <dir>; the DEBUG-only
# ScreenshotRenderer writes the ten PNGs next to the live window, then the
# script kills the app and collects them. No UI automation or Accessibility
# grant needed. (ScreenshotMacTests in CivicsUITests is the live XCUITest
# alternative for interactive runs where the runner prompt can be approved.)
set -euo pipefail

OUT="${1:?usage: capture-screenshots-mac.sh <output dir>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SHOTS=/tmp/civics-mac-shots
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== Building Civics for macOS"
DD=~/Library/Developer/Xcode/DerivedData/Civics-faajjvjpbgghnvaxscjskkybweco
if ! xcodebuild build \
    -project "$ROOT/apple/Civics/Civics.xcodeproj" \
    -scheme Civics \
    -destination 'platform=macOS' \
    SUPPORTED_PLATFORMS="iphoneos iphonesimulator macosx" > "$TMP/build.log" 2>&1; then
  echo "!! build failed — last log lines:" >&2
  tail -40 "$TMP/build.log" >&2
  exit 1
fi
APP="$DD/Build/Products/Debug/Civics.app"
[ -d "$APP" ] || { echo "!! not found: $APP" >&2; exit 1; }

# Re-sign the debug build ad-hoc WITHOUT the app sandbox so the render can
# write to $SHOTS (the sandboxed app may only write inside its container,
# which shells can't read without a TCC grant). Rebuilding restores the
# original signature; this changes nothing in the repo.
printf '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict/></plist>' > "$TMP/empty.plist"
codesign --force --deep --sign - --entitlements "$TMP/empty.plist" "$APP"

rm -rf "$SHOTS"
echo "== Launching with -renderScreenshots"
"$APP/Contents/MacOS/Civics" -renderScreenshots "$SHOTS" > "$TMP/app.log" 2>&1 &
APP_PID=$!
for _ in $(seq 1 60); do
  count=$(find "$SHOTS" -name '*.png' 2>/dev/null | wc -l | tr -d ' ' || true)
  [ "$count" = 10 ] && break
  sleep 1
done
kill "$APP_PID" 2>/dev/null || true
count=$(find "$SHOTS" -name '*.png' 2>/dev/null | wc -l | tr -d ' ' || true)
if [ "$count" != 10 ]; then
  echo "!! expected 10 renders, found $count — app log:" >&2
  tail -20 "$TMP/app.log" >&2
  exit 1
fi
mkdir -p "$OUT"
cp -R "$SHOTS"/. "$OUT"/

echo "== Dimensions:"
find "$OUT" -name '*.png' | sort | while read -r f; do
  sips -g pixelWidth -g pixelHeight "$f" | awk -v f="$f" 'NR==1{printf "%s ", f} /pixel/{printf "%s ", $2} END{print ""}'
done

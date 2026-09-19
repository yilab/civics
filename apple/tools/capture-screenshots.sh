#!/bin/bash
# Captures App Store screenshots (English + zh-Hans UI) on the given simulator
# and saves them under <out>/en and <out>/zh-Hans in upload order.
#
#   apple/tools/capture-screenshots.sh "iPhone 17 Pro Max" assets/screenshots/apple/iphone-6.9
#   apple/tools/capture-screenshots.sh "iPad Pro 13-inch (M5)" assets/screenshots/apple/ipad-13
#
# Requires Xcode 16+ (xcresulttool export attachments) and python3.
set -euo pipefail

DEVICE="${1:?usage: capture-screenshots.sh <simulator name> <output dir>}"
OUT="${2:?usage: capture-screenshots.sh <simulator name> <output dir>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Set light appearance and the clean marketing status bar (9:41, full battery).
# Overrides persist on the device across reboots, so shut down afterwards and
# let xcodebuild boot its own test clone — pre-booted/running devices make the
# test runner launch fail preflight checks.
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl ui "$DEVICE" appearance light
xcrun simctl status_bar "$DEVICE" override \
  --time 9:41 --batteryState charged --batteryLevel 100 \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4
xcrun simctl shutdown "$DEVICE"
sleep 2

echo "== Running ScreenshotTests on '$DEVICE' (log: kept on failure only)"
if ! xcodebuild test \
    -project "$ROOT/apple/Civics/Civics.xcodeproj" \
    -scheme Civics \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -only-testing:CivicsUITests/ScreenshotTests \
    -resultBundlePath "$TMP/result.xcresult" > "$TMP/build.log" 2>&1; then
  echo "!! xcodebuild test failed — last log lines:" >&2
  tail -40 "$TMP/build.log" >&2
  exit 1
fi

xcrun xcresulttool export attachments \
  --path "$TMP/result.xcresult" --output-path "$TMP/attachments" > /dev/null

python3 - "$TMP/attachments" "$OUT" <<'EOF'
import json, os, re, shutil, sys

att_dir, out = sys.argv[1], sys.argv[2]
manifest = json.load(open(os.path.join(att_dir, "manifest.json")))
tests = manifest if isinstance(manifest, list) else manifest.get("tests", [])

# XCTAttachment names arrive as "en-01-listen_0_<UUID>.png" in the manifest.
pattern = re.compile(r"^(en|zh)-(.+?)_\d+_[0-9A-Fa-f-]{36}\.png$")
saved = 0
for test in tests:
    for a in test.get("attachments", []):
        m = pattern.match(a.get("suggestedHumanReadableName", ""))
        if not m:
            continue
        locale = {"en": "en", "zh": "zh-Hans"}[m.group(1)]
        dst = os.path.join(out, locale, m.group(2) + ".png")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy(os.path.join(att_dir, a["exportedFileName"]), dst)
        print("saved", dst)
        saved += 1

if saved != 10:
    sys.exit(f"expected 10 screenshots, saved {saved}")
EOF

echo "== Dimensions:"
find "$OUT" -name '*.png' | sort | while read -r f; do
  sips -g pixelWidth -g pixelHeight "$f" | awk -v f="$f" 'NR==1{printf "%s ", f} /pixel/{printf "%s ", $2} END{print ""}'
done

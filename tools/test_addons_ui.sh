#!/bin/bash
# Isolated Add-ons UI fixture: no network, no game files.
set -euo pipefail
cd "$(dirname "$0")/.."
SIM=${SIMULATOR:-iPhone 17 Pro}
SIM_ID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for group in json.load(sys.stdin)["devices"].values() for d in group if sys.argv[1] in (d["name"], d["udid"])]
devices.sort(key=lambda d: d["state"] != "Booted")
print(devices[0]["udid"] if devices else "")' "$SIM")
[ -n "$SIM_ID" ] || { echo "No matching simulator; set SIMULATOR."; exit 2; }
xcrun simctl bootstatus "$SIM_ID" -b > /dev/null
APP=build/wow-launcher/AddOnsFixture.app
mkdir -p "$APP"
xcrun --sdk iphonesimulator clang -target "$(uname -m)-apple-ios17.0-simulator" -fobjc-arc -O1 -g \
    -Wall -Wextra -Werror -Wno-deprecated-declarations \
    -Ilauncher/WoW/AddOns \
    launcher/WoW/AddOns/AddOnsModel.m launcher/WoW/AddOns/AddOnsTOC.m \
    launcher/WoW/AddOns/AddOnsZip.m launcher/WoW/AddOns/AddOnsManager.m \
    launcher/WoW/AddOns/AddOnsWorkarounds.m \
    launcher/WoW/AddOns/AddOnsSources.m launcher/WoW/AddOns/AddOnsViewController.m \
    tests/test_addons_ui.m \
    -framework Foundation -framework UIKit -framework Security \
    -framework UniformTypeIdentifiers -framework CoreGraphics -lz \
    -o "$APP/AddOnsFixture"
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.tolkara.tests.addons-ui</string>
<key>CFBundleExecutable</key><string>AddOnsFixture</string>
<key>CFBundleName</key><string>AddOns UI fixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>17.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
<key>UILaunchScreen</key><dict/>
<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><false/><key>UISceneConfigurations</key><dict/></dict>
<key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string></array>
</dict></plist>
PLIST
codesign --force --sign - "$APP" > /dev/null
xcrun simctl install "$SIM_ID" "$APP"
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
xcrun simctl launch --terminate-running-process --console "$SIM_ID" org.tolkara.tests.addons-ui "$@" 2>&1 | tee "$LOG"
grep -q 'AddOns UIKit PASS:' "$LOG"

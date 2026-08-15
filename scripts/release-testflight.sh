#!/bin/bash
#
# Archive InsightAtlas and upload it to TestFlight.
#
# Use this instead of Xcode's Product > Archive > Distribute. A plain archive
# produces a binary Apple rejects during processing:
#
#   ITMS-90208: Invalid Bundle - The bundle
#   InsightAtlas.app/Frameworks/onnxruntime.framework does not support the
#   minimum OS Version specified in the Info.plist.
#
# sherpa-onnx is an SPM binaryTarget shipping both static and shared
# xcframeworks. The app links the STATIC ones -- the inference code ends up
# inside the app binary -- but SPM embeds the unused dynamic stubs anyway.
# Those stubs declare MinimumOSVersion 15.1 (onnxruntime) and 13.0
# (SherpaOnnxC) against the app's 17.0, and Apple rejects the bundle for it.
#
# Nothing loads them: the app binary has no @rpath load commands for either,
# and there is no dlopen in the source. So they are dropped from the archive
# before export. The export step re-signs, which regenerates CodeResources.
#
# This is not a build phase because neither variant works: declaring the
# frameworks as script outputs collides with SPM's embed step ("Multiple
# commands produce"), and not declaring them means ENABLE_USER_SCRIPT_SANDBOXING
# denies the delete.
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TEAM_ID="${TEAM_ID:-7FLK8MJ588}"
BUILD_DIR="${BUILD_DIR:-$(mktemp -d)}"
ARCHIVE="$BUILD_DIR/InsightAtlas.xcarchive"
STUBS=(onnxruntime SherpaOnnxC)

echo "==> Archiving to $ARCHIVE"
xcodebuild archive \
  -project InsightAtlas.xcodeproj \
  -scheme InsightAtlas \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID"

APP="$ARCHIVE/Products/Applications/InsightAtlas.app"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")"
echo "==> Built $BUILD_NUMBER"

echo "==> Removing unused dynamic framework stubs"
for stub in "${STUBS[@]}"; do
  target="$APP/Frameworks/$stub.framework"
  [ -d "$target" ] || continue
  # Refuse to strip anything the app actually links, in case a future
  # sherpa-onnx release switches to genuine dynamic linking.
  if otool -L "$APP/InsightAtlas" | grep -q "$stub.framework"; then
    echo "error: $stub.framework is dynamically linked; refusing to strip it." >&2
    exit 1
  fi
  rm -rf "$target"
  echo "    removed $stub.framework"
done
rmdir "$APP/Frameworks" 2>/dev/null || true

# The inference code lives in the app binary, not the stubs. If this is ever
# zero, the static link broke and Kokoro would fail at runtime.
symbols="$(strings -a "$APP/InsightAtlas" | grep -ci 'sherpa-onnx\|OfflineTts' || true)"
if [ "$symbols" -eq 0 ]; then
  echo "error: no sherpa-onnx symbols in the app binary; on-device TTS would be broken." >&2
  exit 1
fi
echo "    verified $symbols sherpa-onnx symbols still statically linked"

EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST

echo "==> Uploading $BUILD_NUMBER to App Store Connect"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$BUILD_DIR/export" \
  -allowProvisioningUpdates

echo
echo "==> Uploaded build $BUILD_NUMBER."
echo "    Upload success only means Apple accepted the file. Processing can"
echo "    still reject it -- watch for email from Apple Developer Relations,"
echo "    or check App Store Connect > InsightAtlas > TestFlight."

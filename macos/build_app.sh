#!/usr/bin/env bash
# Build JapaneseTutor.app: compile with SPM, assemble the bundle, ad-hoc sign.
set -e
cd "$(dirname "$0")"

CONFIG="${1:-release}"   # pass "debug" for a faster, unoptimized build
echo "==> Compiling ($CONFIG)"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/JapaneseTutor"
APP="build/JapaneseTutor.app"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/JapaneseTutor"
cp Info.plist "$APP/Contents/Info.plist"

echo "==> Signing (ad-hoc, hardened runtime)"
# Ad-hoc signature is enough for local use; macOS still shows the permission
# prompts driven by the Info.plist usage strings.
codesign --force --deep --options runtime \
    --entitlements entitlements.plist \
    --sign - "$APP"

echo ""
echo "Built $APP"
echo "Launch it with:  ./run.sh   (or: open $APP)"

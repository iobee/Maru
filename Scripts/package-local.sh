#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Maru"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/Release/Local"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
EXECUTABLE_PATH="$CONTENTS_DIR/MacOS/$APP_NAME"
LOCAL_BUNDLE_IDENTIFIER="com.nick.maru.local"

log() {
    printf '==> %s\n' "$*"
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

command -v swift >/dev/null || fail "swift is required to build Maru"
command -v codesign >/dev/null || fail "codesign is required to sign Maru.app"
command -v install_name_tool >/dev/null || fail "install_name_tool is required to prepare the app bundle"

cd "$ROOT_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$ROOT_DIR/.build/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/ModuleCache"

log "Building SwiftPM debug executable"
if [[ "${MARU_SKIP_SWIFT_BUILD:-0}" == "1" ]]; then
    BIN_DIR="${MARU_SWIFT_BIN_DIR:-$ROOT_DIR/.build/arm64-apple-macosx/debug}"
    log "Using existing SwiftPM products from $BIN_DIR"
else
    swift build -c debug
    BIN_DIR="$(swift build -c debug --show-bin-path)"
fi

[[ -x "$BIN_DIR/$APP_NAME" ]] || fail "Missing SwiftPM executable at $BIN_DIR/$APP_NAME"
[[ -d "$BIN_DIR/Sparkle.framework" ]] || fail "Missing Sparkle.framework at $BIN_DIR/Sparkle.framework"

log "Assembling local app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Frameworks" "$CONTENTS_DIR/Resources"

ditto "$BIN_DIR/$APP_NAME" "$EXECUTABLE_PATH"
ditto "$BIN_DIR/Sparkle.framework" "$CONTENTS_DIR/Frameworks/Sparkle.framework"
ditto "$ROOT_DIR/Sources/Maru/Info.plist" "$CONTENTS_DIR/Info.plist"
ditto "$ROOT_DIR/Sources/Maru/Resources/MaruIcon.icns" "$CONTENTS_DIR/Resources/MaruIcon.icns"
ditto "$ROOT_DIR/Sources/Maru/Assets.xcassets/MaruIconMenubar.imageset/MaruIconMenubar.png" "$CONTENTS_DIR/Resources/MaruIconMenubar.png"
ditto "$ROOT_DIR/Sources/Maru/Assets.xcassets/MaruIconMenubar.imageset/MaruIconMenubar@2x.png" "$CONTENTS_DIR/Resources/MaruIconMenubar@2x.png"

/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion zh_CN" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $LOCAL_BUNDLE_IDENTIFIER" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundlePackageType APPL" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 13.0" "$CONTENTS_DIR/Info.plist"

install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXECUTABLE_PATH"

log "Applying local ad-hoc signature"
codesign --force --deep --sign - --timestamp=none "$APP_BUNDLE"

[[ -d "$APP_BUNDLE" ]] || fail "Missing app bundle at $APP_BUNDLE"
[[ -x "$EXECUTABLE_PATH" ]] || fail "Missing app executable"
codesign --verify --deep --strict "$APP_BUNDLE"

log "Local app bundle ready: $APP_BUNDLE"
printf '\nRun it with:\n  open -n %q\n' "$APP_BUNDLE"
printf '\nNote: this local ad-hoc build is for testing only and may require Accessibility permission again after rebuilding.\n'

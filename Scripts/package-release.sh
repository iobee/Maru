#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Maru"
BUNDLE_ID="com.nick.maru"
MIN_MACOS_VERSION="13.0"
SKIP_SMOKE_TEST=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/Release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
DMG_ROOT="$RELEASE_DIR/DMGRoot"
DMG_PATH="$RELEASE_DIR/$APP_NAME.dmg"
PLIST_PATH="$APP_BUNDLE/Contents/Info.plist"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--no-smoke] [--help]

Builds a release app bundle and DMG for $APP_NAME.

Options:
  --no-smoke   Skip launch smoke tests.
  --help       Show this help message.
EOF
}

log() {
    printf '==> %s\n' "$*"
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

detach_existing_dmg_mounts() {
    local mount_points=""

    mount_points="$(hdiutil info | awk -v image_path="$DMG_PATH" '
        /^image-path[[:space:]]*:/ {
            active = (substr($0, index($0, ":") + 2) == image_path)
        }
        active && match($0, /\/Volumes\/.*/) {
            print substr($0, RSTART)
        }
    ')"

    if [[ -z "$mount_points" ]]; then
        return
    fi

    while IFS= read -r mount_point; do
        [[ -n "$mount_point" ]] || continue
        log "Detaching existing DMG mount: $mount_point"
        hdiutil detach "$mount_point" >/dev/null || hdiutil detach "$mount_point" -force >/dev/null || true
    done <<< "$mount_points"
}

plist_set() {
    local key="$1"
    local value="$2"

    if /usr/libexec/PlistBuddy -c "Set :$key $value" "$PLIST_PATH" >/dev/null 2>&1; then
        return
    fi

    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$PLIST_PATH"
}

wait_for_launch() {
    local bundle_path="$1"
    local executable_path="$bundle_path/Contents/MacOS/$APP_NAME"
    local pids=""

    open -n "$bundle_path"

    for _ in {1..20}; do
        pids="$(pgrep -f "$executable_path" || true)"
        if [[ -n "$pids" ]]; then
            log "Launch smoke test passed: $bundle_path"
            kill $pids >/dev/null 2>&1 || true
            sleep 1
            return
        fi
        sleep 0.5
    done

    fail "Launch smoke test failed for $bundle_path"
}

attach_dmg() {
    local output=""
    local mount_point=""

    output="$(hdiutil attach "$DMG_PATH" -nobrowse -readonly)"
    printf '%s\n' "$output"

    mount_point="$(printf '%s\n' "$output" | awk '/\/Volumes\// { for (i = 3; i <= NF; i++) { printf (i == 3 ? "%s" : " %s", $i) }; print "" }' | tail -n 1)"
    [[ -n "$mount_point" ]] || fail "Could not determine mounted DMG path"

    printf '%s\n' "$mount_point"
}

for arg in "$@"; do
    case "$arg" in
        --no-smoke)
            SKIP_SMOKE_TEST=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "Unknown argument: $arg"
            ;;
    esac
done

cd "$ROOT_DIR"

log "Building release binary"
swift build -c release

BUILT_EXECUTABLE="$ROOT_DIR/.build/release/$APP_NAME"
[[ -x "$BUILT_EXECUTABLE" ]] || fail "Missing release executable at $BUILT_EXECUTABLE"

detach_existing_dmg_mounts

log "Creating app bundle"
rm -rf "$APP_BUNDLE" "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$ROOT_DIR/Sources/Maru/Info.plist" "$PLIST_PATH"
plist_set "CFBundleDevelopmentRegion" "zh_CN"
plist_set "CFBundleExecutable" "$APP_NAME"
plist_set "CFBundleIdentifier" "$BUNDLE_ID"
plist_set "CFBundlePackageType" "APPL"
plist_set "LSMinimumSystemVersion" "$MIN_MACOS_VERSION"
plutil -lint "$PLIST_PATH" >/dev/null

cp "$BUILT_EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cp "$ROOT_DIR/Sources/Maru/Resources/MaruIcon.icns" "$APP_BUNDLE/Contents/Resources/MaruIcon.icns"
cp "$ROOT_DIR/Sources/Maru/Resources/MaruIconMenubar.png" "$APP_BUNDLE/Contents/Resources/MaruIconMenubar.png"

log "Signing app bundle with ad-hoc identity"
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$SKIP_SMOKE_TEST" -eq 0 ]]; then
    log "Smoke testing app launch"
    wait_for_launch "$APP_BUNDLE"
fi

log "Creating DMG"
mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH"

log "Verifying DMG"
hdiutil imageinfo "$DMG_PATH" >/dev/null

detach_existing_dmg_mounts
MOUNT_POINT="$(attach_dmg | tail -n 1)"
cleanup_mount() {
    if [[ -n "${MOUNT_POINT:-}" && -d "$MOUNT_POINT" ]]; then
        hdiutil detach "$MOUNT_POINT" >/dev/null || hdiutil detach "$MOUNT_POINT" -force >/dev/null || true
    fi
}
trap cleanup_mount EXIT

MOUNTED_APP="$MOUNT_POINT/$APP_NAME.app"
[[ -d "$MOUNTED_APP" ]] || fail "Missing mounted app at $MOUNTED_APP"
codesign --verify --deep --strict --verbose=2 "$MOUNTED_APP"

if [[ "$SKIP_SMOKE_TEST" -eq 0 ]]; then
    log "Smoke testing mounted DMG app launch"
    wait_for_launch "$MOUNTED_APP"
fi

cleanup_mount
trap - EXIT

log "Package complete"
ls -lh "$APP_BUNDLE/Contents/MacOS/$APP_NAME" "$DMG_PATH"

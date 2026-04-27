#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Maru"
BUNDLE_ID="com.nick.maru"
MIN_MACOS_VERSION="13.0"
SKIP_SMOKE_TEST=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/Release"
SOURCE_PLIST_PATH="$ROOT_DIR/Sources/Maru/Info.plist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$SOURCE_PLIST_PATH")"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
DMG_ROOT="$RELEASE_DIR/DMGRoot"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$APP_VERSION.dmg"
LEGACY_DMG_PATH="$RELEASE_DIR/$APP_NAME.dmg"
APPCAST_PATH="$RELEASE_DIR/appcast.xml"
PLIST_PATH="$APP_BUNDLE/Contents/Info.plist"
SPARKLE_FRAMEWORK_SOURCE="$ROOT_DIR/.build/release/Sparkle.framework"
SPARKLE_FRAMEWORK_DEST="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
RESOURCE_BUNDLE_NAME="${APP_NAME}_${APP_NAME}.bundle"
RESOURCE_BUNDLE_SOURCE="$ROOT_DIR/.build/release/$RESOURCE_BUNDLE_NAME"
RESOURCE_BUNDLE_DEST="$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE_NAME"

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

validate_app_bundle() {
    local bundle_path="$1"
    local executable_path="$bundle_path/Contents/MacOS/$APP_NAME"
    local resource_bundle_path="$bundle_path/Contents/Resources/$RESOURCE_BUNDLE_NAME"
    local sparkle_framework_path="$bundle_path/Contents/Frameworks/Sparkle.framework"

    [[ -d "$bundle_path" ]] || fail "Missing app bundle at $bundle_path"
    [[ -x "$executable_path" ]] || fail "Missing executable at $executable_path"
    [[ -f "$bundle_path/Contents/Info.plist" ]] || fail "Missing Info.plist in $bundle_path"
    [[ -d "$sparkle_framework_path" ]] || fail "Missing Sparkle framework in $bundle_path"
    [[ -d "$resource_bundle_path" ]] || fail "Missing SwiftPM resource bundle: $resource_bundle_path"
    [[ -f "$resource_bundle_path/Resources/MaruIcon.icns" ]] || fail "Missing MaruIcon.icns in $resource_bundle_path"
    [[ -f "$resource_bundle_path/Resources/MaruIconMenubar.png" ]] || fail "Missing MaruIconMenubar.png in $resource_bundle_path"
    [[ -f "$bundle_path/Contents/Resources/MaruIcon.icns" ]] || fail "Missing Finder icon in Contents/Resources"

    otool -L "$executable_path" | grep -Fq "@rpath/Sparkle.framework" \
        || fail "Executable does not link Sparkle through @rpath"
    otool -l "$executable_path" | grep -Fq "@executable_path/../Frameworks" \
        || fail "Executable is missing @executable_path/../Frameworks rpath"
}

direct_launch_smoke_test() {
    local bundle_path="$1"
    local executable_path="$bundle_path/Contents/MacOS/$APP_NAME"
    local stdout_file=""
    local stderr_file=""
    local pid=""
    local status=0

    stdout_file="$(mktemp "${TMPDIR:-/tmp}/maru-launch-stdout.XXXXXX")"
    stderr_file="$(mktemp "${TMPDIR:-/tmp}/maru-launch-stderr.XXXXXX")"

    "$executable_path" >"$stdout_file" 2>"$stderr_file" &
    pid="$!"

    for _ in {1..20}; do
        if kill -0 "$pid" >/dev/null 2>&1; then
            sleep 0.25
            continue
        fi

        wait "$pid"
        status="$?"
        if [[ "$status" -eq 0 ]]; then
            rm -f "$stdout_file" "$stderr_file"
            return 0
        fi

        printf 'Direct launch exited early with status %s\n' "$status" >&2
        sed -n '1,120p' "$stderr_file" >&2
        rm -f "$stdout_file" "$stderr_file"
        return 1
    done

    kill "$pid" >/dev/null 2>&1 || true
    wait "$pid" >/dev/null 2>&1 || true
    rm -f "$stdout_file" "$stderr_file"
}

smoke_test_without_build_resource_bundle() {
    local bundle_path="$1"
    local backup_path="$RESOURCE_BUNDLE_SOURCE.__packaging-smoke-backup__"
    local status=0

    [[ -d "$RESOURCE_BUNDLE_SOURCE" ]] || fail "Missing build resource bundle at $RESOURCE_BUNDLE_SOURCE"
    [[ ! -e "$backup_path" ]] || fail "Temporary backup already exists: $backup_path"

    mv "$RESOURCE_BUNDLE_SOURCE" "$backup_path"
    set +e
    direct_launch_smoke_test "$bundle_path"
    status="$?"
    set -e
    mv "$backup_path" "$RESOURCE_BUNDLE_SOURCE"

    [[ "$status" -eq 0 ]] || fail "Launch failed without build resource fallback for $bundle_path"
    log "Launch smoke test passed without build resource fallback: $bundle_path"
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
if [[ -f "$APPCAST_PATH" ]]; then
    log "Removing stale appcast: $APPCAST_PATH"
fi
rm -rf "$APP_BUNDLE" "$DMG_ROOT" "$DMG_PATH" "$LEGACY_DMG_PATH" "$APPCAST_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks"

cp "$SOURCE_PLIST_PATH" "$PLIST_PATH"
plist_set "CFBundleDevelopmentRegion" "zh_CN"
plist_set "CFBundleExecutable" "$APP_NAME"
plist_set "CFBundleIdentifier" "$BUNDLE_ID"
plist_set "CFBundlePackageType" "APPL"
plist_set "LSMinimumSystemVersion" "$MIN_MACOS_VERSION"
plutil -lint "$PLIST_PATH" >/dev/null

cp "$BUILT_EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

[[ -d "$SPARKLE_FRAMEWORK_SOURCE" ]] || fail "Missing Sparkle framework at $SPARKLE_FRAMEWORK_SOURCE"
ditto "$SPARKLE_FRAMEWORK_SOURCE" "$SPARKLE_FRAMEWORK_DEST"
if ! otool -l "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
fi

[[ -d "$RESOURCE_BUNDLE_SOURCE" ]] || fail "Missing SwiftPM resource bundle at $RESOURCE_BUNDLE_SOURCE"
ditto "$RESOURCE_BUNDLE_SOURCE" "$RESOURCE_BUNDLE_DEST"

cp "$ROOT_DIR/Sources/Maru/Resources/MaruIcon.icns" "$APP_BUNDLE/Contents/Resources/MaruIcon.icns"
cp "$ROOT_DIR/Sources/Maru/Resources/MaruIconMenubar.png" "$APP_BUNDLE/Contents/Resources/MaruIconMenubar.png"

log "Validating app bundle layout"
validate_app_bundle "$APP_BUNDLE"

log "Signing app bundle with ad-hoc identity"
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$SKIP_SMOKE_TEST" -eq 0 ]]; then
    log "Smoke testing app launch without build resource fallback"
    smoke_test_without_build_resource_bundle "$APP_BUNDLE"

    log "Smoke testing app launch"
    wait_for_launch "$APP_BUNDLE"
fi

log "Creating DMG"
mkdir -p "$DMG_ROOT"
ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
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
validate_app_bundle "$MOUNTED_APP"
codesign --verify --deep --strict --verbose=2 "$MOUNTED_APP"

if [[ "$SKIP_SMOKE_TEST" -eq 0 ]]; then
    log "Smoke testing mounted DMG app launch without build resource fallback"
    smoke_test_without_build_resource_bundle "$MOUNTED_APP"

    log "Smoke testing mounted DMG app launch"
    wait_for_launch "$MOUNTED_APP"
fi

cleanup_mount
trap - EXIT

log "Package complete"
ls -lh "$APP_BUNDLE/Contents/MacOS/$APP_NAME" "$DMG_PATH"

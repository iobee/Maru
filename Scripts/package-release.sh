#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Maru"
SKIP_SMOKE_TEST=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/Release"
SOURCE_PLIST_PATH="$ROOT_DIR/Sources/Maru/Info.plist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$SOURCE_PLIST_PATH")"
ARCHIVE_PATH="$RELEASE_DIR/Maru.xcarchive"
EXPORT_PATH="$RELEASE_DIR/Export"
APP_BUNDLE="$EXPORT_PATH/$APP_NAME.app"
DMG_ROOT="$RELEASE_DIR/DMGRoot"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$APP_VERSION.dmg"
LEGACY_DMG_PATH="$RELEASE_DIR/$APP_NAME.dmg"
APPCAST_PATH="$RELEASE_DIR/appcast.xml"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--no-smoke] [--help]

Builds a release app bundle and DMG for $APP_NAME with Xcode archive/export.

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

validate_app_bundle() {
    local bundle_path="$1"
    local executable_path="$bundle_path/Contents/MacOS/$APP_NAME"
    local sparkle_framework_path="$bundle_path/Contents/Frameworks/Sparkle.framework"
    local assets_car_path="$bundle_path/Contents/Resources/Assets.car"
    local asset_info=""
    local linked_libraries=""
    local load_commands=""

    [[ -d "$bundle_path" ]] || fail "Missing app bundle at $bundle_path"
    [[ -x "$executable_path" ]] || fail "Missing executable at $executable_path"
    [[ -f "$bundle_path/Contents/Info.plist" ]] || fail "Missing Info.plist in $bundle_path"
    [[ -d "$sparkle_framework_path" ]] || fail "Missing Sparkle framework in $bundle_path"
    [[ -f "$bundle_path/Contents/Resources/MaruIcon.icns" ]] || fail "Missing MaruIcon.icns in Contents/Resources"
    [[ -f "$assets_car_path" ]] || fail "Missing asset catalog at $assets_car_path"

    asset_info="$(xcrun assetutil --info "$assets_car_path")"
    [[ "$asset_info" == *'"Name" : "MaruIconMenubar"'* ]] || fail "Missing MaruIconMenubar image in asset catalog"

    linked_libraries="$(otool -L "$executable_path")"
    [[ "$linked_libraries" == *"@rpath/Sparkle.framework"* ]] || fail "Executable does not link Sparkle through @rpath"

    load_commands="$(otool -l "$executable_path")"
    [[ "$load_commands" == *"@executable_path/../Frameworks"* ]] || fail "Executable is missing @executable_path/../Frameworks rpath"
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

command -v xcodegen >/dev/null || fail "xcodegen is required to generate Maru.xcodeproj"

log "Generating Xcode project"
xcodegen generate --project "$ROOT_DIR"

log "Cleaning previous build artifacts"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$APP_BUNDLE" "$DMG_ROOT" "$DMG_PATH" "$LEGACY_DMG_PATH" "$APPCAST_PATH"
mkdir -p "$RELEASE_DIR"

log "Archiving with xcodebuild"
xcodebuild archive \
    -project "$ROOT_DIR/Maru.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH"

log "Exporting archive"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$SCRIPT_DIR/ExportOptions.plist"

log "Verifying exported app signature"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

log "Validating app bundle layout"
validate_app_bundle "$APP_BUNDLE"

if [[ "$SKIP_SMOKE_TEST" -eq 0 ]]; then
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
    log "Smoke testing mounted DMG app launch"
    wait_for_launch "$MOUNTED_APP"
fi

cleanup_mount
trap - EXIT

log "Package complete"
ls -lh "$APP_BUNDLE/Contents/MacOS/$APP_NAME" "$DMG_PATH"

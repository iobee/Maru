#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Maru"
PUBLISH=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/Release"
SOURCE_PLIST_PATH="$ROOT_DIR/Sources/Maru/Info.plist"
REPOSITORY="${MARU_GITHUB_REPOSITORY:-iobee/Maru}"
PUBLIC_APPCAST_URL="${MARU_PUBLIC_APPCAST_URL:-https://iobee.github.io/Maru/appcast.xml}"
SIGNING_IDENTITY="${MACOS_SIGN_IDENTITY:-${MARU_CODE_SIGN_IDENTITY:-Maru Release Signing}}"
LOGIN_KEYCHAIN="${MARU_LOGIN_KEYCHAIN:-${HOME}/Library/Keychains/login.keychain-db}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--publish] [--help]

Without arguments, runs the local read-only release preflight.
With --publish, tests, packages, tags, creates or resumes the GitHub prerelease,
publishes the Sparkle appcast, and verifies the public feed.

The publish path resumes only when the tag matches HEAD and the existing DMG has
the expected version, build, and release-certificate fingerprint. It never
clobbers a tag or release asset.

Optional environment:
  MARU_SPARKLE_PRIVATE_KEY_FILE   Sparkle EdDSA key file (preferred over Keychain UI).
  MARU_CODE_SIGN_IDENTITY         Stable signing identity (default: Maru Release Signing).
EOF
}

log() {
    printf '==> %s\n' "$*"
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

gh_clean() {
    env -u GITHUB_TOKEN -u GH_TOKEN gh "$@"
}

resolve_sparkle_key_file() {
    if [[ -n "${MARU_SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
        printf '%s\n' "$MARU_SPARKLE_PRIVATE_KEY_FILE"
    elif [[ -f "${HOME}/Downloads/maru-sparkle-ed25519-key" ]]; then
        printf '%s\n' "${HOME}/Downloads/maru-sparkle-ed25519-key"
    elif [[ -f "/private/tmp/maru-sparkle-ed25519-key" ]]; then
        printf '%s\n' "/private/tmp/maru-sparkle-ed25519-key"
    else
        fail "Sparkle private-key backup was not found. Set MARU_SPARKLE_PRIVATE_KEY_FILE; do not generate a new key."
    fi
}

read_appcast_file_value() {
    local appcast_path="$1"
    local element_name="$2"

    xmllint --xpath "string(//*[local-name()='$element_name'][1])" "$appcast_path" 2>/dev/null \
        || true
}

read_appcast_enclosure_url() {
    local appcast_path="$1"

    xmllint --xpath 'string(//*[local-name()="enclosure"][1]/@url)' "$appcast_path" 2>/dev/null \
        || true
}

resolve_remote_tag_commit() {
    local tag="$1"
    local output=""
    local commit=""

    output="$(git ls-remote --tags origin "refs/tags/$tag" "refs/tags/$tag^{}")"
    commit="$(printf '%s\n' "$output" | awk '$2 ~ /\^\{\}$/ { print $1; exit }')"
    if [[ -z "$commit" ]]; then
        commit="$(printf '%s\n' "$output" | awk 'NF >= 2 { print $1; exit }')"
    fi
    printf '%s\n' "$commit"
}

validate_published_dmg() {
    local dmg_path="$1"
    local mount_path="$2"
    local mounted_app="$mount_path/$APP_NAME.app"
    local mounted_version=""
    local mounted_build=""
    local identities=""
    local certificate_hash=""
    local requirement_output=""

    hdiutil imageinfo "$dmg_path" >/dev/null
    mkdir -p "$mount_path"
    hdiutil attach "$dmg_path" -nobrowse -readonly -mountpoint "$mount_path" >/dev/null
    MOUNT_POINT="$mount_path"

    [[ -d "$mounted_app" ]] || fail "Published DMG does not contain $APP_NAME.app"
    mounted_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$mounted_app/Contents/Info.plist")"
    mounted_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$mounted_app/Contents/Info.plist")"
    [[ "$mounted_version" == "$VERSION" ]] \
        || fail "Published DMG contains version $mounted_version, expected $VERSION"
    [[ "$mounted_build" == "$BUILD" ]] \
        || fail "Published DMG contains build $mounted_build, expected $BUILD"

    codesign --verify --deep --strict --verbose=2 "$mounted_app"
    identities="$(security find-identity -v -p codesigning "$LOGIN_KEYCHAIN")"
    certificate_hash="$(printf '%s\n' "$identities" \
        | awk -v identity="\"$SIGNING_IDENTITY\"" 'index($0, identity) { print tolower($2); exit }')"
    [[ -n "$certificate_hash" ]] \
        || fail "Could not resolve the certificate fingerprint for $SIGNING_IDENTITY"
    # Developer ID requirements identify the team rather than a literal leaf hash.
    # Compare the embedded leaf certificate directly for both signing types.
    local cert_dir=""
    local actual_hash=""
    cert_dir="$(mktemp -d "${TMPDIR:-/tmp}/maru-cert.XXXXXX")"
    codesign -d --extract-certificates="$cert_dir/cert" "$mounted_app"
    actual_hash="$(shasum -a 1 "$cert_dir/cert0" | awk '{ print $1 }')"
    rm -rf "$cert_dir"
    [[ "$actual_hash" == "$certificate_hash" ]] \
        || fail "Published DMG does not use the certificate behind $SIGNING_IDENTITY"
    if [[ "${MACOS_RELEASE:-0}" == "1" ]]; then
        python3 "$SCRIPT_DIR/macos-release.py" verify "$mounted_app" --notarized
        python3 "$SCRIPT_DIR/macos-release.py" verify "$dmg_path" --notarized
    fi

    hdiutil detach "$mount_path" >/dev/null
    MOUNT_POINT=""
}

for arg in "$@"; do
    case "$arg" in
        --publish)
            PUBLISH=1
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

if [[ "$PUBLISH" -eq 0 ]]; then
    exec "$SCRIPT_DIR/release-preflight.sh"
fi

[[ "${MACOS_RELEASE:-0}" == "1" ]] \
    || fail "Publishing requires Developer ID signing and notarization. Load .env.release.local first."

SPARKLE_KEY_FILE="$(resolve_sparkle_key_file)"
export MARU_SPARKLE_PRIVATE_KEY_FILE="$SPARKLE_KEY_FILE"

log "Running complete local and remote release preflight"
"$SCRIPT_DIR/release-preflight.sh" --publish

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_PLIST_PATH")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SOURCE_PLIST_PATH")"
TAG="v$VERSION"
HEAD_COMMIT="$(git rev-parse HEAD)"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
GENERATE_APPCAST="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
TEMP_ROOT="$(mktemp -d /private/tmp/maru-release.XXXXXX)"
PAGES_DIR="$TEMP_ROOT/gh-pages"
FEED_DIR="$TEMP_ROOT/feed"
MOUNT_POINT=""

cleanup() {
    if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
        hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
    fi
    if [[ -d "$PAGES_DIR" ]]; then
        git worktree remove --force "$PAGES_DIR" >/dev/null 2>&1 || true
    fi
    if [[ "$TEMP_ROOT" == /private/tmp/maru-release.* && -d "$TEMP_ROOT" ]]; then
        rm -rf "$TEMP_ROOT"
    fi
}
trap cleanup EXIT

RELEASE_EXISTS=0
ASSET_EXISTS=0
PUBLISHED_ASSET_DIR="$TEMP_ROOT/published-asset"
mkdir -p "$PUBLISHED_ASSET_DIR"

if gh_clean release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
    RELEASE_EXISTS=1
    EXISTING_ASSETS="$(gh_clean release view "$TAG" --repo "$REPOSITORY" --json assets --jq '.assets[].name')"
    if grep -Fx "$DMG_NAME" <<< "$EXISTING_ASSETS" >/dev/null; then
        ASSET_EXISTS=1
        log "Downloading the existing release asset for safe resume validation"
        gh_clean release download "$TAG" \
            --repo "$REPOSITORY" \
            --pattern "$DMG_NAME" \
            --dir "$PUBLISHED_ASSET_DIR"
        DMG_PATH="$PUBLISHED_ASSET_DIR/$DMG_NAME"
        validate_published_dmg "$DMG_PATH" "$TEMP_ROOT/mounted-existing-dmg"
        DMG_SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{ print $1 }')"
        log "Existing release asset has the expected version, build, and stable signature"
    fi
fi

log "Running Swift tests"
swift test --quiet

[[ -x "$GENERATE_APPCAST" ]] \
    || fail "Sparkle generate_appcast was not resolved by SwiftPM: $GENERATE_APPCAST"

if [[ "$ASSET_EXISTS" -eq 0 ]]; then
    DMG_PATH="$RELEASE_DIR/$DMG_NAME"
    log "Building and verifying signed release DMG"
    "$SCRIPT_DIR/package-release.sh" --no-smoke
    [[ -f "$DMG_PATH" ]] || fail "Package script did not create $DMG_PATH"
    hdiutil imageinfo "$DMG_PATH" >/dev/null
    DMG_SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{ print $1 }')"
else
    log "Skipping a nondeterministic rebuild and resuming from the verified published DMG"
fi

log "Rechecking release invariants after tests and artifact validation"
"$SCRIPT_DIR/release-preflight.sh" --publish

if git show-ref --verify --quiet "refs/tags/$TAG"; then
    LOCAL_TAG_COMMIT="$(git rev-list -n 1 "$TAG")"
    [[ "$LOCAL_TAG_COMMIT" == "$HEAD_COMMIT" ]] \
        || fail "Local tag $TAG no longer matches HEAD. Refusing to overwrite it."
else
    log "Creating annotated tag $TAG"
    git tag -a "$TAG" -m "$APP_NAME $VERSION"
fi

REMOTE_TAG_COMMIT="$(resolve_remote_tag_commit "$TAG")"
if [[ -z "$REMOTE_TAG_COMMIT" ]]; then
    log "Pushing tag $TAG"
    git push origin "$TAG"
elif [[ "$REMOTE_TAG_COMMIT" != "$HEAD_COMMIT" ]]; then
    fail "Remote tag $TAG points to $REMOTE_TAG_COMMIT, not $HEAD_COMMIT. Refusing to overwrite it."
else
    log "Remote tag already matches HEAD: $TAG"
fi

if [[ "$RELEASE_EXISTS" -eq 1 ]]; then
    log "Resuming existing GitHub Release $TAG"
else
    log "Creating GitHub prerelease $TAG"
    gh_clean release create "$TAG" \
        --repo "$REPOSITORY" \
        --title "$APP_NAME $VERSION" \
        --target "$HEAD_COMMIT" \
        --generate-notes \
        --prerelease
    RELEASE_EXISTS=1
fi

if [[ "$ASSET_EXISTS" -eq 0 ]]; then
    log "Uploading $DMG_NAME"
    gh_clean release upload "$TAG" "$DMG_PATH" --repo "$REPOSITORY"
    log "Downloading the uploaded asset for a byte-for-byte verification"
    gh_clean release download "$TAG" \
        --repo "$REPOSITORY" \
        --pattern "$DMG_NAME" \
        --dir "$PUBLISHED_ASSET_DIR"
    PUBLISHED_SHA256="$(shasum -a 256 "$PUBLISHED_ASSET_DIR/$DMG_NAME" | awk '{ print $1 }')"
    [[ "$PUBLISHED_SHA256" == "$DMG_SHA256" ]] \
        || fail "GitHub returned $DMG_NAME with a different SHA-256. Stop; do not clobber the asset."
    validate_published_dmg "$PUBLISHED_ASSET_DIR/$DMG_NAME" "$TEMP_ROOT/mounted-uploaded-dmg"
    log "Published release asset is byte-for-byte identical and has the expected signature"
fi
gh_clean release edit "$TAG" --repo "$REPOSITORY" --draft=false --prerelease >/dev/null

EXPECTED_APPCAST_URL="https://github.com/$REPOSITORY/releases/download/$TAG/$DMG_NAME"
CURRENT_PUBLIC_APPCAST="$TEMP_ROOT/current-public-appcast.xml"
if curl -fsSL "$PUBLIC_APPCAST_URL?release-audit=$BUILD" -o "$CURRENT_PUBLIC_APPCAST"; then
    CURRENT_PUBLIC_BUILD="$(read_appcast_file_value "$CURRENT_PUBLIC_APPCAST" version)"
    CURRENT_PUBLIC_VERSION="$(read_appcast_file_value "$CURRENT_PUBLIC_APPCAST" shortVersionString)"
    CURRENT_PUBLIC_URL="$(read_appcast_enclosure_url "$CURRENT_PUBLIC_APPCAST")"
    if [[ "$CURRENT_PUBLIC_BUILD" == "$BUILD" && "$CURRENT_PUBLIC_VERSION" == "$VERSION" && "$CURRENT_PUBLIC_URL" == "$EXPECTED_APPCAST_URL" ]]; then
        RELEASE_URL="$(gh_clean release view "$TAG" --repo "$REPOSITORY" --json url --jq '.url')"
        log "Release asset and public appcast are already complete; appcast republish skipped"
        printf '    release: %s\n' "$RELEASE_URL"
        printf '    SHA-256: %s\n' "$DMG_SHA256"
        printf '    appcast: %s\n' "$PUBLIC_APPCAST_URL"
        exit 0
    fi
fi

mkdir -p "$FEED_DIR"
cp "$DMG_PATH" "$FEED_DIR/$DMG_NAME"
gh_clean release view "$TAG" --repo "$REPOSITORY" --json body --jq '.body // ""' \
    > "$FEED_DIR/$APP_NAME-$VERSION.md"
if [[ ! -s "$FEED_DIR/$APP_NAME-$VERSION.md" ]]; then
    rm -f "$FEED_DIR/$APP_NAME-$VERSION.md"
fi

log "Generating Sparkle appcast with the explicit key-file path"
"$GENERATE_APPCAST" \
    --ed-key-file "$SPARKLE_KEY_FILE" \
    --download-url-prefix "https://github.com/$REPOSITORY/releases/download/$TAG/" \
    --link "https://github.com/$REPOSITORY/releases/tag/$TAG" \
    --embed-release-notes \
    --maximum-deltas 0 \
    -o "$FEED_DIR/appcast.xml" \
    "$FEED_DIR"

xmllint --noout "$FEED_DIR/appcast.xml"
APPCAST_BUILD="$(read_appcast_file_value "$FEED_DIR/appcast.xml" version)"
APPCAST_VERSION="$(read_appcast_file_value "$FEED_DIR/appcast.xml" shortVersionString)"
APPCAST_URL="$(read_appcast_enclosure_url "$FEED_DIR/appcast.xml")"
[[ "$APPCAST_BUILD" == "$BUILD" ]] \
    || fail "Generated appcast build is $APPCAST_BUILD, expected $BUILD"
[[ "$APPCAST_VERSION" == "$VERSION" ]] \
    || fail "Generated appcast version is $APPCAST_VERSION, expected $VERSION"
[[ "$APPCAST_URL" == "$EXPECTED_APPCAST_URL" ]] \
    || fail "Generated appcast URL is unexpected: $APPCAST_URL"

log "Publishing appcast.xml to gh-pages"
git fetch --quiet origin gh-pages
git worktree add --detach "$PAGES_DIR" origin/gh-pages >/dev/null
cp "$FEED_DIR/appcast.xml" "$PAGES_DIR/appcast.xml"
git -C "$PAGES_DIR" add appcast.xml
if git -C "$PAGES_DIR" diff --cached --quiet; then
    log "gh-pages already contains the generated appcast"
else
    git -C "$PAGES_DIR" commit -m "Publish $VERSION appcast"
    git -C "$PAGES_DIR" push origin HEAD:gh-pages
fi

log "Waiting for the public Sparkle feed"
PUBLIC_APPCAST_PATH="$TEMP_ROOT/public-appcast.xml"
PUBLIC_MATCHED=0
for attempt in {1..12}; do
    if curl -fsSL "$PUBLIC_APPCAST_URL?release=$BUILD&attempt=$attempt" -o "$PUBLIC_APPCAST_PATH"; then
        PUBLIC_BUILD="$(read_appcast_file_value "$PUBLIC_APPCAST_PATH" version)"
        PUBLIC_VERSION="$(read_appcast_file_value "$PUBLIC_APPCAST_PATH" shortVersionString)"
        PUBLIC_URL="$(read_appcast_enclosure_url "$PUBLIC_APPCAST_PATH")"
        if [[ "$PUBLIC_BUILD" == "$BUILD" && "$PUBLIC_VERSION" == "$VERSION" && "$PUBLIC_URL" == "$APPCAST_URL" ]]; then
            PUBLIC_MATCHED=1
            break
        fi
    fi
    sleep 5
done
[[ "$PUBLIC_MATCHED" -eq 1 ]] \
    || fail "Public appcast did not converge to $VERSION ($BUILD) within 60 seconds. Remote state is preserved for inspection."

RELEASE_URL="$(gh_clean release view "$TAG" --repo "$REPOSITORY" --json url --jq '.url')"
log "Release published and verified"
printf '    release: %s\n' "$RELEASE_URL"
printf '    artifact: %s\n' "$DMG_PATH"
printf '    SHA-256: %s\n' "$DMG_SHA256"
printf '    appcast: %s\n' "$PUBLIC_APPCAST_URL"

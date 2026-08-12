#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Maru"
CHECK_REMOTE=0
ALLOW_DIRTY=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_PLIST_PATH="$ROOT_DIR/Sources/Maru/Info.plist"
PROJECT_CONFIG_PATH="$ROOT_DIR/project.yml"
REPOSITORY="${MARU_GITHUB_REPOSITORY:-iobee/Maru}"
RELEASE_BRANCH="${MARU_RELEASE_BRANCH:-main}"
SIGNING_IDENTITY="${MARU_CODE_SIGN_IDENTITY:-Maru Release Signing}"
LOGIN_KEYCHAIN="${MARU_LOGIN_KEYCHAIN:-${HOME}/Library/Keychains/login.keychain-db}"
PUBLIC_APPCAST_URL="${MARU_PUBLIC_APPCAST_URL:-https://iobee.github.io/Maru/appcast.xml}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--publish] [--allow-dirty] [--help]

Checks every local prerequisite needed to create a stable Maru release.
No files, tags, releases, or remote branches are changed.

Options:
  --publish       Also check the upstream branch, GitHub, remote tag, and public appcast.
  --allow-dirty   Permit a dirty worktree for script development only. Never use to publish.
  --help          Show this help message.

Optional environment:
  MARU_SPARKLE_PRIVATE_KEY_FILE   Sparkle EdDSA private-key file. The file is never printed.
  MARU_CODE_SIGN_IDENTITY         Stable signing identity (default: Maru Release Signing).
  MARU_LOGIN_KEYCHAIN             Keychain to inspect (default: login.keychain-db).
  MARU_RELEASE_BRANCH             Required release branch (default: main).
  MARU_GITHUB_REPOSITORY          GitHub owner/repository (default: iobee/Maru).
EOF
}

log() {
    printf '==> %s\n' "$*"
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command is missing: $1"
}

resolve_sparkle_key_file() {
    local candidate=""

    if [[ -n "${MARU_SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
        candidate="$MARU_SPARKLE_PRIVATE_KEY_FILE"
    elif [[ -f "${HOME}/Downloads/maru-sparkle-ed25519-key" ]]; then
        candidate="${HOME}/Downloads/maru-sparkle-ed25519-key"
    elif [[ -f "/private/tmp/maru-sparkle-ed25519-key" ]]; then
        candidate="/private/tmp/maru-sparkle-ed25519-key"
    else
        fail "Sparkle private-key backup was not found. Set MARU_SPARKLE_PRIVATE_KEY_FILE; do not generate or rotate a key."
    fi

    printf '%s\n' "$candidate"
}

validate_sparkle_key_metadata() {
    local key_file="$1"
    local key_size=""
    local key_mode=""
    local key_owner=""
    local current_user=""

    [[ -f "$key_file" ]] || fail "Sparkle private-key file is missing: $key_file"

    key_size="$(/usr/bin/stat -f '%z' "$key_file")"
    key_mode="$(/usr/bin/stat -f '%Lp' "$key_file")"
    key_owner="$(/usr/bin/stat -f '%Su' "$key_file")"
    current_user="$(id -un)"

    [[ "$key_size" == "44" ]] \
        || fail "Sparkle private-key file has unexpected size ($key_size bytes, expected 44); the file may be empty or malformed."
    case "$key_mode" in
        400|600) ;;
        *) fail "Sparkle private-key file must be owner-only (mode 400 or 600); found $key_mode." ;;
    esac
    [[ "$key_owner" == "$current_user" ]] \
        || fail "Sparkle private-key file is owned by $key_owner instead of $current_user."
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

read_appcast_value() {
    local appcast="$1"
    local element_name="$2"

    printf '%s' "$appcast" \
        | xmllint --xpath "string(//*[local-name()='$element_name'][1])" - 2>/dev/null \
        || true
}

for arg in "$@"; do
    case "$arg" in
        --publish)
            CHECK_REMOTE=1
            ;;
        --allow-dirty)
            ALLOW_DIRTY=1
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

for required_command in git swift xcodegen security codesign hdiutil xmllint shasum awk; do
    require_command "$required_command"
done
if [[ "$CHECK_REMOTE" -eq 1 ]]; then
    require_command gh
    require_command curl
fi

[[ -f "$SOURCE_PLIST_PATH" ]] || fail "Missing source Info.plist: $SOURCE_PLIST_PATH"
[[ -f "$PROJECT_CONFIG_PATH" ]] || fail "Missing project.yml: $PROJECT_CONFIG_PATH"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_PLIST_PATH")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SOURCE_PLIST_PATH")"
PROJECT_VERSION="$(awk '/^[[:space:]]*MARKETING_VERSION:/ { print $2; exit }' "$PROJECT_CONFIG_PATH")"
PROJECT_BUILD="$(awk '/^[[:space:]]*CURRENT_PROJECT_VERSION:/ { print $2; exit }' "$PROJECT_CONFIG_PATH")"
TAG="v$VERSION"
HEAD_COMMIT="$(git rev-parse HEAD)"
BRANCH="$(git symbolic-ref --quiet --short HEAD)" || fail "Release checkout is detached; use $RELEASE_BRANCH."

[[ "$VERSION" == "$PROJECT_VERSION" ]] \
    || fail "Version mismatch: Info.plist=$VERSION, project.yml=$PROJECT_VERSION"
[[ "$BUILD" == "$PROJECT_BUILD" ]] \
    || fail "Build mismatch: Info.plist=$BUILD, project.yml=$PROJECT_BUILD"
[[ "$BUILD" =~ ^[0-9]+$ ]] || fail "CFBundleVersion must be an integer; found $BUILD"
[[ "$BRANCH" == "$RELEASE_BRANCH" ]] \
    || fail "Releases must run from $RELEASE_BRANCH; current branch is $BRANCH"

if [[ "$ALLOW_DIRTY" -eq 0 ]]; then
    git diff --quiet || fail "Worktree has unstaged changes. Commit only the intended release changes first."
    git diff --cached --quiet || fail "Worktree has staged but uncommitted changes."
    [[ -z "$(git ls-files --others --exclude-standard)" ]] \
        || fail "Worktree has untracked files. Preserve or commit them intentionally before publishing."
else
    log "Dirty-worktree check bypassed for local script validation"
fi

if git show-ref --verify --quiet "refs/tags/$TAG"; then
    LOCAL_TAG_COMMIT="$(git rev-list -n 1 "$TAG")"
    [[ "$LOCAL_TAG_COMMIT" == "$HEAD_COMMIT" ]] \
        || fail "Local tag $TAG points to $LOCAL_TAG_COMMIT, not HEAD $HEAD_COMMIT. Bump the version instead of overwriting the tag."
    log "Existing local tag is consistent with HEAD: $TAG"
fi

IDENTITIES="$(security find-identity -v -p codesigning "$LOGIN_KEYCHAIN" 2>&1 || true)"
if ! grep -F "$SIGNING_IDENTITY" <<< "$IDENTITIES" >/dev/null; then
    if [[ -n "${CODEX_SANDBOX:-}" ]]; then
        fail "Signing identity '$SIGNING_IDENTITY' is not visible. Codex sandboxing can falsely report 0 valid identities; rerun this preflight outside the sandbox before concluding the identity is missing."
    fi
    fail "No matching stable signing identity found in $LOGIN_KEYCHAIN: $SIGNING_IDENTITY"
fi

SPARKLE_KEY_FILE="$(resolve_sparkle_key_file)"
validate_sparkle_key_metadata "$SPARKLE_KEY_FILE"

if [[ "$CHECK_REMOTE" -eq 1 ]]; then
    [[ "$ALLOW_DIRTY" -eq 0 ]] || fail "--allow-dirty cannot be combined with --publish"

    ORIGIN_URL="$(git remote get-url origin)"
    case "$ORIGIN_URL" in
        *github.com/iobee/Maru.git|*github.com/iobee/Maru) ;;
        *) fail "origin does not point to iobee/Maru: $ORIGIN_URL" ;;
    esac

    if [[ "${CODEX_SANDBOX_NETWORK_DISABLED:-}" == "1" ]]; then
        log "Codex reports sandboxed networking; publishing checks must be run with approved outside-sandbox access"
    fi

    log "Refreshing origin/$RELEASE_BRANCH"
    git fetch --quiet origin "$RELEASE_BRANCH"
    REMOTE_BRANCH_COMMIT="$(git rev-parse "refs/remotes/origin/$RELEASE_BRANCH")"
    [[ "$HEAD_COMMIT" == "$REMOTE_BRANCH_COMMIT" ]] \
        || fail "HEAD ($HEAD_COMMIT) must exactly match origin/$RELEASE_BRANCH ($REMOTE_BRANCH_COMMIT) before tagging."

    env -u GITHUB_TOKEN -u GH_TOKEN gh auth status >/dev/null \
        || fail "GitHub CLI authentication failed after clearing GITHUB_TOKEN and GH_TOKEN."

    REMOTE_TAG_COMMIT="$(resolve_remote_tag_commit "$TAG")"
    if [[ -n "$REMOTE_TAG_COMMIT" ]]; then
        [[ "$REMOTE_TAG_COMMIT" == "$HEAD_COMMIT" ]] \
            || fail "Remote tag $TAG points to $REMOTE_TAG_COMMIT, not HEAD $HEAD_COMMIT. Never overwrite a published tag."
        log "Existing remote tag is consistent with HEAD: $TAG"
    fi

    if env -u GITHUB_TOKEN -u GH_TOKEN gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
        [[ -n "$REMOTE_TAG_COMMIT" ]] \
            || fail "GitHub Release $TAG exists without a matching remote tag. Stop and inspect it manually."
        log "Existing GitHub Release can be resumed safely: $TAG"
    fi

    PUBLIC_APPCAST="$(curl -fsSL "$PUBLIC_APPCAST_URL")" \
        || fail "Could not read public appcast: $PUBLIC_APPCAST_URL"
    PUBLIC_BUILD="$(read_appcast_value "$PUBLIC_APPCAST" version)"
    PUBLIC_VERSION="$(read_appcast_value "$PUBLIC_APPCAST" shortVersionString)"
    if [[ "$PUBLIC_BUILD" =~ ^[0-9]+$ ]]; then
        (( BUILD >= PUBLIC_BUILD )) \
            || fail "Build $BUILD is older than public Sparkle build $PUBLIC_BUILD. Increase CFBundleVersion."
        if (( BUILD == PUBLIC_BUILD )); then
            [[ "$VERSION" == "$PUBLIC_VERSION" ]] \
                || fail "Build $BUILD is already public as $PUBLIC_VERSION, not $VERSION. Increase CFBundleVersion."
            [[ -n "$REMOTE_TAG_COMMIT" ]] \
                || fail "Version $VERSION is already public but tag $TAG is missing. Stop and inspect remote state."
            log "Public appcast already contains this exact release: $VERSION ($BUILD)"
        fi
    else
        fail "Public appcast did not expose a numeric Sparkle build version."
    fi
fi

log "Release preflight passed"
printf '    version: %s\n' "$VERSION"
printf '    build: %s\n' "$BUILD"
printf '    tag: %s\n' "$TAG"
printf '    branch/commit: %s / %s\n' "$BRANCH" "$HEAD_COMMIT"
printf '    signing identity: %s\n' "$SIGNING_IDENTITY"
printf '    Sparkle key: %s (%s bytes, mode %s; contents not read)\n' \
    "$SPARKLE_KEY_FILE" \
    "$(/usr/bin/stat -f '%z' "$SPARKLE_KEY_FILE")" \
    "$(/usr/bin/stat -f '%Lp' "$SPARKLE_KEY_FILE")"

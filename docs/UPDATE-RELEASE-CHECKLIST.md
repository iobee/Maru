# Maru Update Release Checklist

## Canonical Local Release Path

Until all GitHub Actions signing secrets are confirmed, the proven release path
for this repository is the local signed flow. Use the repository scripts instead
of reconstructing the individual commands from shell history:

```bash
# Optional read-only preview. Run this outside a restrictive Codex sandbox.
./Scripts/release-preflight.sh --publish

# Canonical one-command publish; it reruns the complete preflight itself.
./Scripts/publish-release.sh --publish
```

`publish-release.sh` runs tests, builds and verifies the signed DMG, creates or
resumes the annotated tag and GitHub prerelease, generates the Sparkle appcast,
publishes it to `gh-pages`, and verifies the public feed. It resumes only when
the existing tag matches the current commit and the published DMG has the
expected version, build, and exact release-certificate fingerprint. Newly
uploaded bytes are downloaded and hash-checked. The script never uses
`--clobber` and refuses to overwrite a mismatched published artifact.

Running `publish-release.sh` without `--publish` performs only the local preflight.

### Release Invariants

- Run Keychain, code-signing, `hdiutil`, and GitHub publishing checks outside a
  restrictive Codex sandbox. A sandboxed `security find-identity` can incorrectly
  report `0 valid identities` even when the login keychain contains a usable
  `Maru Release Signing` identity. Always repeat that check outside the sandbox
  before asking for a new certificate or `.p12`.
- The local stable identity is `Maru Release Signing` in the login keychain.
- Keep the Sparkle private key separate from the code-signing identity. On the
  current release Mac, the validated backup is
  `~/Downloads/maru-sparkle-ed25519-key`; it must be 44 bytes and owner-only
  (`chmod 600`). The scripts inspect metadata but never print its contents.
- Local appcast generation uses Sparkle's official `--ed-key-file` path so a
  Keychain authorization dialog cannot leave a headless release hanging.
- Local `gh` commands always clear `GITHUB_TOKEN` and `GH_TOKEN`, allowing the
  validated keyring-backed `gh` login to be used.
- `Info.plist`, `project.yml`, the commit, tag, DMG name, GitHub Release, and
  Sparkle version/build must agree. Never rotate a key or overwrite a tag/asset
  to repair a mismatch; increment the version/build instead.
- The GitHub Actions workflows are an alternative only after confirming all
  listed repository secrets. Their presence alone does not mean CI publishing
  is configured.

## Sparkle Keys

- `SUPublicEDKey` is committed in `Sources/Maru/Info.plist`.
- The private EdDSA key is stored outside the repository.
- Never commit private key material.
- Local `generate_appcast` can read the private key from the macOS Keychain by default,
  but the canonical local release script uses the validated key-file backup to avoid
  interactive Keychain prompts.
- CI uses the `SPARKLE_PRIVATE_KEY` repository secret and passes it to Sparkle with `--ed-key-file`.

### Retrieve the Sparkle Private Key

When invoked directly without `--ed-key-file`, Sparkle's `generate_appcast` asks
the macOS login Keychain for the private key created by Sparkle's `generate_keys`
tool. The end-to-end release script deliberately supplies the validated backup
file instead.

Check that the local Keychain has the Sparkle key only when diagnosing or restoring
the backup:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys -p
```

Export the private key for GitHub Actions:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x /private/tmp/maru-sparkle-ed25519-key
pbcopy < /private/tmp/maru-sparkle-ed25519-key
```

Store the copied value as the `SPARKLE_PRIVATE_KEY` repository secret. The
exported file is sensitive private key material; delete it after the secret has
been set.

If setting up a new machine from the CI secret, write the secret value to a
temporary file and import it into the local Keychain:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys -f /path/to/sparkle-ed25519-key
```

## Local Behavior Testing Without a Signing Identity

Use the local packaging script when validating window behavior on a machine
that does not have the stable release certificate:

```bash
./Scripts/package-local.sh
open -n Release/Local/Maru.app
```

This creates a real local `.app` bundle with an ad-hoc signature and the bundle
identifier `com.nick.maru.local`. It is for local testing only and must never be
uploaded as a release artifact. Because its signature changes when rebuilt,
macOS may require Accessibility permission again.

## Stable Release Signing

- Public release DMGs must be signed with the same stable code-signing certificate for every release.
- Do not publish ad-hoc signed DMGs. macOS Accessibility/TCC authorization is tied to the app's designated code requirement, and ad-hoc updates can make users authorize Maru again after every install.
- A paid Apple Developer account is not required for this specific TCC stability fix. A persistent self-signed code-signing certificate, for example `Maru Release Signing`, is enough to give Maru a certificate-based designated requirement across releases.
- A self-signed certificate does not replace Developer ID notarization. Users may still need to right-click Open or approve Gatekeeper warnings after downloading Maru.
- Do not rotate the release signing certificate unless you accept one more Accessibility reauthorization for existing users.
- `Scripts/package-release.sh` defaults to `MARU_CODE_SIGN_IDENTITY="Maru Release Signing"` and validates that the exported app is not ad-hoc signed or cdhash-only.
- If Maru later uses a paid Apple Developer account, set `MARU_CODE_SIGN_IDENTITY="Developer ID Application"` and optionally `MARU_DEVELOPMENT_TEAM`.
- GitHub Actions requires these repository secrets for the `Release DMG` workflow:
  - `MARU_RELEASE_CERTIFICATE_BASE64`
  - `MARU_RELEASE_CERTIFICATE_PASSWORD`
  - `MARU_KEYCHAIN_PASSWORD`
- Optional GitHub Actions repository variable:
  - `MARU_CODE_SIGN_IDENTITY` defaults to `Maru Release Signing`
- Optional GitHub Actions repository secret for Developer ID signing:
  - `MARU_DEVELOPMENT_TEAM`

### Create a Self-Signed Release Certificate

Use this path when publishing without an Apple Developer account:

1. Open Keychain Access.
2. Choose Certificate Assistant > Create a Certificate.
3. Name it `Maru Release Signing`.
4. Use a self-signed root identity with the Code Signing certificate type.
5. Store the certificate and private key in the login keychain.
6. Verify the identity:

```bash
security find-identity -v -p codesigning | grep "Maru Release Signing"
```

For GitHub Actions, export that same certificate and private key as a `.p12`, then set:

```bash
base64 -i MaruReleaseSigning.p12 | pbcopy
```

Store the copied value in `MARU_RELEASE_CERTIFICATE_BASE64` and the export password in `MARU_RELEASE_CERTIFICATE_PASSWORD`.

### Retrieve the Release Signing Certificate

Local DMG packaging does not read a certificate file. `Scripts/package-release.sh`
looks up a code-signing identity in the macOS Keychain by name:

```bash
security find-identity -v -p codesigning | grep "Maru Release Signing"
```

The expected default identity name is `Maru Release Signing`. Override it only
when intentionally using a different stable certificate:

```bash
MARU_CODE_SIGN_IDENTITY="Developer ID Application" ./Scripts/package-release.sh
```

For GitHub Actions, export the same identity from Keychain Access:

1. Open Keychain Access.
2. Select the login keychain.
3. Open My Certificates.
4. Select `Maru Release Signing`.
5. Export it as `MaruReleaseSigning.p12` and set a strong export password.

Then encode the `.p12` for the `Release DMG` workflow:

```bash
base64 -i MaruReleaseSigning.p12 | pbcopy
```

Store the copied value in `MARU_RELEASE_CERTIFICATE_BASE64`, the export password
in `MARU_RELEASE_CERTIFICATE_PASSWORD`, and any random temporary keychain
password in `MARU_KEYCHAIN_PASSWORD`.

After packaging, confirm the exported app is certificate-based and not ad-hoc:

```bash
codesign -dv --verbose=4 Release/Export/Maru.app
codesign -dr - Release/Export/Maru.app
```

## Version Bump

Update both version sources before packaging:

- `Sources/Maru/Info.plist`
  - `CFBundleShortVersionString`: human version, for example `1.0.0-beta.4`
  - `CFBundleVersion`: monotonically increasing build number, for example `4`
- `project.yml`
  - `MARKETING_VERSION`
  - `CURRENT_PROJECT_VERSION`

Sparkle compares updates using `CFBundleVersion` / `sparkle:version`; do not publish a release without increasing it.

## Release Steps

1. Update `CFBundleShortVersionString`.
2. Increment `CFBundleVersion`.
3. Update `project.yml` to the same marketing version and build number.
4. Commit the intended version/release changes and push them to `origin/main`.
5. Run `./Scripts/publish-release.sh --publish` outside the sandbox. It performs
   the complete preflight before changing remote state.
6. Verify an older Maru build detects the new version.

The sections below document the component commands for diagnosis and recovery.
They are not the preferred routine path now that the end-to-end script exists.

## Manual DMG Packaging

Use the Xcode archive/export package script:

```bash
swift test
./Scripts/package-release.sh
```

For CI or other headless environments:

```bash
./Scripts/package-release.sh --no-smoke
```

Expected artifacts:

- `Release/Export/Maru.app`
- `Release/Maru-<version>.dmg`

The script validates stable certificate-based code signing, Sparkle framework embedding, `@rpath`, the menu bar icon asset in `Assets.car`, and the DMG contents.

## Manual GitHub Release Upload

Use this when the user asks to publish the latest local DMG directly:

```bash
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/Maru/Info.plist)"
TAG="v$VERSION"
DMG="Release/Maru-$VERSION.dmg"

ls -lh "$DMG"
shasum -a 256 "$DMG"

env -u GITHUB_TOKEN -u GH_TOKEN gh release view "$TAG" --repo iobee/Maru
env -u GITHUB_TOKEN -u GH_TOKEN gh release upload "$TAG" "$DMG" --clobber --repo iobee/Maru
env -u GITHUB_TOKEN -u GH_TOKEN gh release edit "$TAG" --draft=false --prerelease --repo iobee/Maru
env -u GITHUB_TOKEN -u GH_TOKEN gh release view "$TAG" --repo iobee/Maru
```

If the release does not exist:

```bash
env -u GITHUB_TOKEN -u GH_TOKEN gh release create "$TAG" "$DMG" \
  --repo iobee/Maru \
  --title "Maru $VERSION" \
  --target "$(git rev-parse HEAD)" \
  --generate-notes \
  --prerelease
```

Note: this repository has previously had an invalid `GITHUB_TOKEN` in the local shell environment while a valid `gh` keyring login existed. Use `env -u GITHUB_TOKEN -u GH_TOKEN` for local `gh` commands if that happens.

## Manual Sparkle Appcast Publish

Use this after the DMG is uploaded to GitHub Releases:

```bash
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/Maru/Info.plist)"
TAG="v$VERSION"
FEED_DIR="Release/SparkleFeed"
SPARKLE_KEY_FILE="${MARU_SPARKLE_PRIVATE_KEY_FILE:-$HOME/Downloads/maru-sparkle-ed25519-key}"

rm -rf "$FEED_DIR"
mkdir -p "$FEED_DIR"
cp "Release/Maru-$VERSION.dmg" "$FEED_DIR/"

.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
  --ed-key-file "$SPARKLE_KEY_FILE" \
  --download-url-prefix "https://github.com/iobee/Maru/releases/download/$TAG/" \
  --link "https://github.com/iobee/Maru/releases/tag/$TAG" \
  --maximum-deltas 0 \
  -o "$FEED_DIR/appcast.xml" \
  "$FEED_DIR"

xmllint --noout "$FEED_DIR/appcast.xml"
xmllint --xpath 'string(//*[local-name()="version"])' "$FEED_DIR/appcast.xml"
xmllint --xpath 'string(//*[local-name()="shortVersionString"])' "$FEED_DIR/appcast.xml"
```

Publish to GitHub Pages:

```bash
rm -rf /tmp/maru-gh-pages
git fetch origin gh-pages
git worktree add /tmp/maru-gh-pages origin/gh-pages
cp "$FEED_DIR/appcast.xml" /tmp/maru-gh-pages/appcast.xml
xmllint --noout /tmp/maru-gh-pages/appcast.xml
git -C /tmp/maru-gh-pages diff -- appcast.xml
git -C /tmp/maru-gh-pages add appcast.xml
git -C /tmp/maru-gh-pages commit -m "Publish ${VERSION} appcast"
git -C /tmp/maru-gh-pages push origin HEAD:gh-pages
git worktree remove /tmp/maru-gh-pages
```

Verify the public feed:

```bash
curl -fsSL https://iobee.github.io/Maru/appcast.xml | head -40
```

Do not manually write Sparkle signatures. Use `generate_appcast`.

Hardware requirement rule:

- If the DMG app binary is universal (`x86_64 arm64`), do not add `sparkle:hardwareRequirements=arm64`.
- Only include hardware constraints when the release artifact actually requires them.

## GitHub Actions Release Flow

1. Run the `Release DMG` workflow.
   - It builds the release DMG with `Scripts/package-release.sh --no-smoke`.
   - It creates or updates the GitHub Release and uploads `Release/Maru-<version>.dmg`.
2. Run the `Sparkle Appcast` workflow with the same release tag.
   - It downloads the DMG from GitHub Releases.
   - It signs the update and generates `appcast.xml` with Sparkle `generate_appcast`.
   - It publishes `appcast.xml` to the `gh-pages` branch root.

Required repository secret:

- `SPARKLE_PRIVATE_KEY`: Sparkle EdDSA private key generated by `generate_keys`.
- `MARU_RELEASE_CERTIFICATE_BASE64`: Base64-encoded `.p12` export for the persistent release signing certificate.
- `MARU_RELEASE_CERTIFICATE_PASSWORD`: Password for the `.p12` export.
- `MARU_KEYCHAIN_PASSWORD`: Temporary CI keychain password.

Repository setup:

- GitHub Pages should serve from the `gh-pages` branch root so `appcast.xml` is available at `https://iobee.github.io/Maru/appcast.xml`.

## Validation

- `检查更新…` opens Sparkle's manual update check UI.
- About page probe does not open an update install window.
- Missing or invalid appcast logs an error but does not crash Maru.

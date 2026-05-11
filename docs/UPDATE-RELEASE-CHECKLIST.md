# Maru Update Release Checklist

## Sparkle Keys

- `SUPublicEDKey` is committed in `Sources/Maru/Info.plist`.
- The private EdDSA key is stored outside the repository.
- Never commit private key material.
- Local `generate_appcast` reads the private key from the macOS Keychain by default.
- CI uses the `SPARKLE_PRIVATE_KEY` repository secret and passes it to Sparkle with `--ed-key-file`.

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
4. Run `swift test`.
5. Package with `./Scripts/package-release.sh`.
6. Upload `Release/Maru-<version>.dmg` to GitHub Releases.
7. Publish the release as a prerelease while the app is still in beta.
8. Generate Sparkle appcast and EdDSA signatures.
9. Publish `appcast.xml` to GitHub Pages at `https://iobee.github.io/Maru/appcast.xml`.
10. Verify the public appcast URL returns the new version.
11. Verify an older Maru build detects the new version.

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

rm -rf "$FEED_DIR"
mkdir -p "$FEED_DIR"
cp "Release/Maru-$VERSION.dmg" "$FEED_DIR/"

.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
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

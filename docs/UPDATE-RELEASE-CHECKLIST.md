# Maru Update Release Checklist

## Sparkle Keys

- `SUPublicEDKey` is committed in `Sources/Maru/Info.plist`.
- The private EdDSA key is stored outside the repository.
- Never commit private key material.

## Release Steps

1. Update `CFBundleShortVersionString`.
2. Increment `CFBundleVersion`.
3. Build release app bundle.
4. Sign the app.
5. Notarize and staple.
6. Package as `.dmg` or `.zip`.
7. Generate Sparkle appcast and EdDSA signatures.
8. Upload package to GitHub Releases.
9. Publish `appcast.xml` to GitHub Pages at `https://iobee.github.io/Maru/appcast.xml`.
10. Verify an older Maru build detects the new version.

## Validation

- `检查更新…` opens Sparkle's manual update check UI.
- About page probe does not open an update install window.
- Missing or invalid appcast logs an error but does not crash Maru.

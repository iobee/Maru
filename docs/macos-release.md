# Developer ID releases

Build from `main` after the release changes have been merged. Keep experimental
features on their own branches. Existing versions/tags/assets must not be overwritten;
bump the version/build before publishing replacement binaries.

On the release Mac, create an ignored `.env.release.local` containing public
settings only (never a private key, `.p12`, or app-specific password):

```sh
export MACOS_RELEASE=1
export MACOS_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export MACOS_TEAM_ID='TEAMID'
export MACOS_NOTARY_PROFILE='your-notary-profile'
```

The profile must already exist in Keychain, created with Apple's `notarytool`.
On this Mac, the existing `forma-notary` profile may be reused across apps.

```sh
source .env.release.local
./Scripts/package-release.sh --no-smoke
# Only when a new version is approved for publication:
./Scripts/publish-release.sh --publish
```

The app and all embedded code are signed with Developer ID, secure timestamps,
and hardened runtime. App notarization must be Accepted before the app is stapled
and archived. The DMG is then signed, notarized, stapled, and assessed by Gatekeeper.
A rejected or pending submission stops the pipeline before that artifact is published.

Apple can take longer than a build job. `MACOS_NOTARY_TIMEOUT` defaults to `20m`.
Pending submissions exit 75 and are recorded beside the artifact in `.notary/`.
Resume the exact artifact with `python3 Scripts/macos-release.py notarize
/path/to/App.app` (or the DMG), using the same environment. Do not rebuild it merely
to poll: a new build has a new signature and requires a new submission.

## CI configuration

CI is gated on Developer ID certificate and notarization credentials. Adding the
workflow does not configure repository secrets. Never commit or print these values.
The workflow stores notarization credentials in a temporary file-based keychain
and sets `MACOS_NOTARY_KEYCHAIN` so every notarytool command reads that same keychain.
Local builds can leave this unset to use the existing default Keychain profile.
Set `MACOS_SIGN_IDENTITY` and `MACOS_TEAM_ID` as repository variables. Supply
`MACOS_CERTIFICATE_BASE64`, `MACOS_CERTIFICATE_PASSWORD`, `APPLE_ID`, and
`APPLE_APP_SPECIFIC_PASSWORD` as repository secrets. HiTranslator also needs its
existing `RELEASES_GITHUB_TOKEN` for the separate `iobee/hiTranslator-releases` repo.

Existing installations keep their bundle identifiers. Moving from ad-hoc or
self-signed builds to Developer ID can require a one-time permission reauthorization.
Application code-signing certificates and Maru's Sparkle EdDSA key are separate;
this migration does not rotate the Sparkle key.

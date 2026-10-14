import XCTest

final class ReleaseSigningConfigurationTests: XCTestCase {
    func testReleaseBuildUsesStableSigningIdentityFromEnvironment() throws {
        let project = try repositoryFileContents("project.yml")

        XCTAssertTrue(
            project.contains("Release:\n      CODE_SIGN_IDENTITY: \"$(MARU_CODE_SIGN_IDENTITY)\""),
            "Release builds must use the same stable signing identity so macOS TCC permissions survive app updates."
        )
        XCTAssertTrue(
            project.contains("DEVELOPMENT_TEAM: \"$(MARU_DEVELOPMENT_TEAM)\""),
            "Developer ID release signing should take the optional team identifier from the packaging environment, not from source-controlled secrets."
        )
    }

    func testPackageScriptRejectsAdHocReleaseSignatures() throws {
        let script = try repositoryFileContents("Scripts/package-release.sh")

        XCTAssertTrue(
            script.contains("Signature=adhoc"),
            "The release script must explicitly reject ad-hoc signatures."
        )
        XCTAssertTrue(
            script.contains("certificate leaf[subject.OU]") || script.contains("Authority="),
            "The release script must validate that exported apps have a certificate-based signature."
        )
    }

    func testReleasePreflightGuardsKnownLocalFailureModes() throws {
        let script = try repositoryFileContents("Scripts/release-preflight.sh")

        XCTAssertTrue(script.contains("CODEX_SANDBOX"))
        XCTAssertTrue(script.contains("Maru Release Signing"))
        XCTAssertTrue(script.contains("expected 44"))
        XCTAssertTrue(script.contains("mode 400 or 600"))
        XCTAssertTrue(script.contains("env -u GITHUB_TOKEN -u GH_TOKEN"))
    }

    func testPublishReleaseUsesNonInteractiveSigningAndNeverClobbersAssets() throws {
        let script = try repositoryFileContents("Scripts/publish-release.sh")

        XCTAssertTrue(script.contains("--ed-key-file"))
        XCTAssertFalse(script.contains("--clobber"))
        XCTAssertTrue(script.contains("validate_published_dmg"))
        XCTAssertTrue(script.contains("read_appcast_enclosure_url"))
        XCTAssertTrue(script.contains("PUBLIC_APPCAST_URL"))
    }

    private func repositoryFileContents(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

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

    private func repositoryFileContents(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

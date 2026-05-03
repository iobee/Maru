import Foundation

struct AppStorageLocations {
    let configurationDirectory: URL
    let logDirectory: URL

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        applicationSupportDirectory: URL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
    ) -> AppStorageLocations {
        let fallbackApplicationDirectory = applicationSupportDirectory.appendingPathComponent("Maru")
        let configurationDirectory = absoluteXDGDirectory(
            named: "XDG_CONFIG_HOME",
            environment: environment
        )?.appendingPathComponent("Maru") ?? fallbackApplicationDirectory

        let logDirectory = absoluteXDGDirectory(
            named: "XDG_STATE_HOME",
            environment: environment
        )?.appendingPathComponent("Maru").appendingPathComponent("Logs")
            ?? fallbackApplicationDirectory.appendingPathComponent("Logs")

        return AppStorageLocations(
            configurationDirectory: configurationDirectory,
            logDirectory: logDirectory
        )
    }

    private static func absoluteXDGDirectory(named name: String, environment: [String: String]) -> URL? {
        guard let value = environment[name], !value.isEmpty else {
            return nil
        }

        guard value.hasPrefix("/") else {
            return nil
        }

        return URL(fileURLWithPath: value, isDirectory: true)
    }
}

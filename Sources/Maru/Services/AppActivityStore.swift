import Foundation
import Combine

enum AppActivityEventKind: String, Codable, CaseIterable {
    case launched
    case activated
    case window
    case action
    case success
    case skipped
    case failure

    var iconName: String {
        switch self {
        case .launched: return "power"
        case .activated: return "arrow.up.forward.app"
        case .window: return "macwindow"
        case .action: return "wand.and.stars"
        case .success: return "checkmark.circle.fill"
        case .skipped: return "forward.end.fill"
        case .failure: return "exclamationmark.triangle.fill"
        }
    }
}

struct AppActivityEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let appName: String
    let bundleIdentifier: String
    let processIdentifier: Int32?
    let kind: AppActivityEventKind
    let title: String
    let detail: String
    let windowTitle: String?
    let trigger: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        appName: String,
        bundleIdentifier: String,
        processIdentifier: Int32? = nil,
        kind: AppActivityEventKind,
        title: String,
        detail: String,
        windowTitle: String? = nil,
        trigger: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.kind = kind
        self.title = title
        self.detail = detail
        self.windowTitle = windowTitle
        self.trigger = trigger
    }
}

final class AppActivityStore: ObservableObject {
    static let shared = AppActivityStore()
    static let defaultMaximumEventCount = 1_200

    @Published private(set) var events: [AppActivityEvent]

    private let storageURL: URL
    private let maximumEventCount: Int

    init(
        storageURL: URL? = nil,
        storageLocations: AppStorageLocations = AppStorageLocations.resolve(),
        maximumEventCount: Int = AppActivityStore.defaultMaximumEventCount
    ) {
        self.storageURL = storageURL
            ?? storageLocations.logDirectory.appendingPathComponent("app_activity.json")
        self.maximumEventCount = max(1, maximumEventCount)

        try? FileManager.default.createDirectory(
            at: self.storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        events = Self.loadEvents(from: self.storageURL, maximumEventCount: self.maximumEventCount)
    }

    func record(_ event: AppActivityEvent) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.record(event)
            }
            return
        }

        events.append(event)
        if events.count > maximumEventCount {
            events.removeFirst(events.count - maximumEventCount)
        }
        persistEvents()
    }

    func clearEvents() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.clearEvents()
            }
            return
        }

        events.removeAll()
        persistEvents()
    }

    private func persistEvents() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(events)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            AppLogger.shared.log("保存应用动态失败: \(error.localizedDescription)", level: .error)
        }
    }

    private static func loadEvents(from storageURL: URL, maximumEventCount: Int) -> [AppActivityEvent] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([AppActivityEvent].self, from: data)
                .sorted { $0.timestamp < $1.timestamp }
            return Array(decoded.suffix(maximumEventCount))
        } catch {
            AppLogger.shared.log("加载应用动态失败: \(error.localizedDescription)", level: .warning)
            return []
        }
    }
}

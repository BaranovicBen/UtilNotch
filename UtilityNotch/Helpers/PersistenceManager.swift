import Foundation

/// Lightweight local persistence — stores Codable values as JSON files in Application Support.
/// No cloud sync. Data survives force-quit and relaunch.
final class PersistenceManager {

    static let shared = PersistenceManager()

    private let baseURL: URL

    private init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        baseURL = appSupport.appendingPathComponent("UtilityNotch", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    // MARK: - Write

    func save<T: Encodable>(_ value: T, key: PersistenceKey) {
        let url = baseURL.appendingPathComponent("\(key.rawValue).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Read

    func load<T: Decodable>(_ type: T.Type, key: PersistenceKey) -> T? {
        let url = baseURL.appendingPathComponent("\(key.rawValue).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}

// MARK: - Keys

enum PersistenceKey: String {
    case todos          = "todos"
    case notes          = "notes"
    case moduleOrder    = "moduleOrder"
    case settings       = "settings"
}

// MARK: - Persisted Settings Snapshot

struct PersistedSettings: Codable {
    var menuBarSummaryMode: String
    var showHoverLabels: Bool
    var inactivityTimeout: Double
    var defaultModuleID: String?
    var activeModuleID: String
    var showMusicWaveform: Bool
}

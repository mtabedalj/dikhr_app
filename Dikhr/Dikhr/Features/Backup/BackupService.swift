import Foundation

/// Builds and applies single-file JSON backups ("نسخ احتياطي"), matching the
/// original's BackupFileListView export/import idea.
///
/// Schema:
/// {"format":"dikhr-backup","version":1,"favorites":[...],"counters":[...],
///  "streaks":{...},"settings":{"lang","accentIndex",...}}
///
/// Import is a safe merge: schema keys are validated, unknown keys are ignored,
/// favorites are unioned, streaks merge per-day and only whitelisted settings
/// keys with the right value type are applied.
enum BackupService {
    static let formatKey = "dikhr-backup"
    static let version = 1

    // MARK: - Document

    struct BackupCounter: Codable {
        var id: String?
        var name: String
        var count: Int
        var target: Int
    }

    struct BackupStreak: Codable {
        var date: String
        var prayers: Bool
        var athkarCount: Int
        var quran: Bool
    }

    /// A settings value: typed so wrong-typed values from a corrupt file are rejected.
    enum BackupScalar: Codable, Equatable {
        case string(String)
        case int(Int)
        case bool(Bool)
        case double(Double)

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let v = try? c.decode(Bool.self) { self = .bool(v) }
            else if let v = try? c.decode(Int.self) { self = .int(v) }
            else if let v = try? c.decode(Double.self) { self = .double(v) }
            else if let v = try? c.decode(String.self) { self = .string(v) }
            else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported scalar") }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .string(let v): try c.encode(v)
            case .int(let v): try c.encode(v)
            case .bool(let v): try c.encode(v)
            case .double(let v): try c.encode(v)
            }
        }
    }

    struct Document: Codable {
        var format = BackupService.formatKey
        var version = BackupService.version
        var favorites: [String]
        var counters: [BackupCounter]
        var streaks: [String: BackupStreak]
        var settings: [String: BackupScalar]
    }

    enum BackupError: LocalizedError {
        case badFile

        var errorDescription: String? {
            switch self {
            case .badFile: return DikhrStrings.tr("ملف النسخة الاحتياطية غير صالح", "Invalid backup file")
            }
        }
    }

    /// Settings keys we back up and accept back. Unknown keys are ignored on import.
    static let settingsKeys: Set<String> = [
        "lang", "accentIndex", "fontSizeBoost", "hijriAdjustment",
        "showTranslation", "appearanceMode", "useAutoLocation",
    ]

    // MARK: - Export

    static func makeDocument(from defaults: UserDefaults = .standard) -> Document {
        var settings: [String: BackupScalar] = [:]
        for key in settingsKeys {
            switch defaults.object(forKey: key) {
            case let v as String: settings[key] = .string(v)
            case let v as Int: settings[key] = .int(v)
            case let v as Bool: settings[key] = .bool(v)
            case let v as Double: settings[key] = .double(v)
            default: break
            }
        }
        let streaks = StreaksStore.records().reduce(into: [String: BackupStreak]()) { acc, pair in
            acc[pair.key] = BackupStreak(date: pair.value.date,
                                         prayers: pair.value.prayers,
                                         athkarCount: pair.value.athkarCount,
                                         quran: pair.value.quran)
        }
        return Document(favorites: SettingsStore.shared.favorites.sorted(),
                        counters: CounterStore.load().map {
                            BackupCounter(id: $0.id.uuidString, name: $0.name,
                                          count: $0.count, target: $0.target)
                        },
                        streaks: streaks,
                        settings: settings)
    }

    /// Writes the backup file into tmp and returns its URL to hand to ShareLink.
    static func exportURL() throws -> URL {
        let doc = makeDocument()
        let data = try JSONEncoder().encode(doc)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dikhr-backup.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import

    static func importData(_ data: Data,
                           from defaults: UserDefaults = .standard) throws {
        let doc: Document
        do {
            doc = try JSONDecoder().decode(Document.self, from: data)
        } catch {
            throw BackupError.badFile
        }
        guard doc.format == formatKey, doc.version >= 1 else {
            throw BackupError.badFile
        }

        // Favorites: union with current.
        let store = SettingsStore.shared
        store.favorites = store.favorites.union(Set(doc.favorites))

        // Counters: restore the backed-up list (user's own file).
        if !doc.counters.isEmpty {
            let restored = doc.counters.map { c -> SavedCounter in
                let id = c.id.flatMap(UUID.init(uuidString:)) ?? UUID()
                return SavedCounter(id: id, name: c.name, count: c.count, target: c.target)
            }
            CounterStore.save(restored)
        }

        // Streaks: merge per-day.
        if !doc.streaks.isEmpty {
            var existing = StreaksStore.records()
            for (key, streak) in doc.streaks {
                existing[key] = DayCheckin(date: streak.date,
                                           prayers: streak.prayers,
                                           athkarCount: streak.athkarCount,
                                           quran: streak.quran)
            }
            if let data = try? JSONEncoder().encode(existing) {
                defaults.set(data, forKey: "streaks")
            }
        }

        // Settings: only whitelisted keys, type-checked. Published values persist
        // through SettingsStore's didSet.
        for (key, value) in doc.settings where settingsKeys.contains(key) {
            switch (key, value) {
            case ("lang", .string(let v)):
                if let lang = SettingsStore.Language(rawValue: v) { store.lang = lang }
            case ("accentIndex", .int(let v)) where (0..<ThemePalette.colors.count).contains(v):
                store.accentIndex = v
            case ("accentIndex", .double(let v)) where v >= 0 && v < Double(ThemePalette.colors.count):
                store.accentIndex = Int(v)
            case ("fontSizeBoost", .bool(let v)):
                store.fontSizeBoost = v
            case ("showTranslation", .bool(let v)):
                store.showTranslation = v
            case ("hijriAdjustment", .int(let v)):
                store.hijriAdjustment = max(-3, min(3, v))
            case ("appearanceMode", .string(let v)) where ["system", "light", "dark"].contains(v):
                store.appearanceMode = v
            case ("useAutoLocation", .bool(let v)):
                store.useAutoLocation = v
            default:
                break
            }
        }
    }

    static func importURL(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        try importData(data)
    }
}
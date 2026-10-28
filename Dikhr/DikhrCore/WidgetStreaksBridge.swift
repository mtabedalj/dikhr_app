import Foundation

// MARK: - Widget streaks bridge (MyWidgetTaskProgressElement parity)
//
// The app tracks daily check-ins with StreaksStore (app target, UserDefaults.standard).
// Widget processes cannot read the app's own defaults container, so this bridge keeps
// a MIRRORED copy of the same "streaks" JSON in the app group
// ("group.dev.dikhr.app.shared"). The schema is identical to StreaksStore's
// [String: DayCheckin] dict (keys date / prayers / athkarCount / quran / nawafil),
// so the raw bytes can be copied verbatim and decoded here.
//
// WIRING REQUESTED (main session, one line — do not let the app drift stale):
//   Dikhr/Data/StreaksStore.swift → inside update(_:), after persisting, add:
//     DikhrStreaksBridge.mirrorFromAppDefaults()
//   (and when a check-in changes, refresh the widget timelines:
//     WidgetCenter.shared.reloadTimelines(ofKind: "DikhrDailyTasks"))

enum DikhrStreaksBridge {
    /// App-group key holding the mirrored streak JSON (same schema as the app's "streaks").
    static let mirroredKey = "streaks"

    /// Copies the app's current "streaks" JSON into the app group. Call from the
    /// APP process after any check-in write; absent data leaves the mirror untouched
    /// (the function is also harmless if a widget ever ran it).
    static func mirrorFromAppDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "streaks") else { return }
        DikhrShared.defaults.set(data, forKey: mirroredKey)
    }

    // MARK: - Reading (widget side)

    /// Today's check-in read from the mirrored copy; all-false defaults when
    /// nothing has been mirrored yet (pre-wiring) or the day is unchecked.
    static func today(on date: Date = Date()) -> MirroredCheckin {
        records()[dayKey(date)] ?? MirroredCheckin(date: dayKey(date))
    }

    static func records() -> [String: MirroredCheckin] {
        guard let data = DikhrShared.defaults.data(forKey: mirroredKey),
              let dict = try? JSONDecoder().decode([String: MirroredCheckin].self, from: data)
        else { return [:] }
        return dict
    }

    /// Current streak over the mirrored records — mirrors StreaksStore.streak(for:)
    /// semantics (today unchecked doesn't break the streak).
    static func streak(field: KeyPath<MirroredCheckin, Bool>, from date: Date = Date()) -> Int {
        let all = records()
        var day = date
        var streak = 0
        func checked(_ d: Date) -> Bool {
            all[dayKey(d)].map { $0[keyPath: field] } ?? false
        }
        if !checked(day) {
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while checked(day) {
            streak += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    static func athkarStreak(from date: Date = Date()) -> Int {
        let all = records()
        var day = date
        var streak = 0
        if (all[dayKey(day)]?.athkarCount ?? 0) == 0 {
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while (all[dayKey(day)]?.athkarCount ?? 0) > 0 {
            streak += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    /// The worship-tracker day ratio the app uses (AthkarFollowupView.refresh):
    /// [prayers, quran, nawafil, athkar-counted] done of 4.
    static func dayRatio(on date: Date = Date()) -> Double {
        let day = today(on: date)
        let done = [day.prayers, day.quran, day.nawafil, day.athkarCount > 0]
            .filter { $0 }.count
        return Double(done) / 4.0
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }
}

/// Decode-safe mirror of the app's DayCheckin (older backups lack `nawafil`).
struct MirroredCheckin: Codable, Hashable {
    var date: String
    var prayers: Bool = false
    var athkarCount: Int = 0
    var quran: Bool = false
    var nawafil: Bool = false

    private enum CodingKeys: String, CodingKey {
        case date, prayers, athkarCount, quran, nawafil
    }

    init(date: String) {
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        prayers = try c.decodeIfPresent(Bool.self, forKey: .prayers) ?? false
        athkarCount = try c.decodeIfPresent(Int.self, forKey: .athkarCount) ?? 0
        quran = try c.decodeIfPresent(Bool.self, forKey: .quran) ?? false
        nawafil = try c.decodeIfPresent(Bool.self, forKey: .nawafil) ?? false
    }
}
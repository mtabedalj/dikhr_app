import Foundation

struct DayCheckin: Codable, Hashable {
    var date: String
    var prayers: Bool = false
    var athkarCount: Int = 0
    var quran: Bool = false
    var nawafil: Bool = false

    private enum CodingKeys: String, CodingKey {
        case date, prayers, athkarCount, quran, nawafil
    }
}

// Decode-safe decoding: older persisted "streaks" JSON (and files restored by
// BackupService) lack the nawafil key — decode it as false instead of failing
// the whole dictionary. Defined in an extension so the memberwise initializer
// (used by BackupService) stays available.
extension DayCheckin {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        prayers = try c.decodeIfPresent(Bool.self, forKey: .prayers) ?? false
        athkarCount = try c.decodeIfPresent(Int.self, forKey: .athkarCount) ?? 0
        quran = try c.decodeIfPresent(Bool.self, forKey: .quran) ?? false
        nawafil = try c.decodeIfPresent(Bool.self, forKey: .nawafil) ?? false
    }
}

/// Tracks daily "مداومة" (persistence) for prayers, athkar, Quran and nawafil,
/// matching the original's streaks feature (binary evidence: streak/streakNawafil,
/// "مداومة الصلوات/الأذكار/القرآن/النوافل", FOUR streaks with current + best).
/// Best streaks are computed at write time on every check-in change and
/// persisted under the original's key names:
///   prayers  -> dailyTasks_currentStreak / dailyTasks_bestStreak (default streaks)
///   athkar   -> dailyTasks_athkarStreakCurrent / dailyTasks_athkarStreakBest
///   quran    -> dailyTasks_quranStreakCurrent / dailyTasks_quranStreakBest
///   nawafil  -> dailyTasks_nawafilStreakCurrent / dailyTasks_nawafilStreakBest
enum StreaksStore {
    private static func makeKeyFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }

    private static func todayKey() -> String {
        makeKeyFormatter().string(from: Date())
    }

    static func records() -> [String: DayCheckin] {
        guard let data = UserDefaults.standard.data(forKey: "streaks"),
              let dict = try? JSONDecoder().decode([String: DayCheckin].self, from: data)
        else { return [:] }
        return dict
    }

    static func today() -> DayCheckin {
        records()[todayKey()] ?? DayCheckin(date: todayKey())
    }

    static func update(_ transform: (inout DayCheckin) -> Void) {
        var all = records()
        var day = all[todayKey()] ?? DayCheckin(date: todayKey())
        transform(&day)
        all[todayKey()] = day
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: "streaks")
        }
        persistBests()
    }

    static func setPrayers(_ value: Bool) { update { $0.prayers = value } }
    static func setQuran(_ value: Bool) { update { $0.quran = value } }
    static func setNawafil(_ value: Bool) { update { $0.nawafil = value } }
    static func addAthkar(_ count: Int = 1) { update { $0.athkarCount += count } }

    // MARK: - Current streaks

    static func streak(for field: KeyPath<DayCheckin, Bool>) -> Int {
        let all = records()
        var streak = 0
        var day = Date()
        func checked(_ date: Date) -> Bool {
            (all[key(date)].map { $0[keyPath: field] }) ?? false
        }
        // Allow today's unchecked day without breaking the streak (start from yesterday)
        if !checked(day) {
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while checked(day) {
            streak += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    static func athkarStreak() -> Int {
        let all = records()
        var streak = 0
        var day = Date()
        if (all[key(day)]?.athkarCount ?? 0) == 0 {
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while (all[key(day)]?.athkarCount ?? 0) > 0 {
            streak += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    static func nawafilStreak() -> Int { streak(for: \.nawafil) }

    // MARK: - Best streaks (persisted, computed at write time)

    /// Recomputes all four current streaks and raises the persisted best when
    /// a current streak exceeds it. Called after every update(_:) — the best
    /// never decreases, so it is only touched on a new maximum.
    static func persistBests() {
        let defaults = UserDefaults.standard
        let currents: [(String, Int)] = [
            ("dailyTasks_bestStreak", streak(for: \.prayers)),
            ("dailyTasks_athkarStreakBest", athkarStreak()),
            ("dailyTasks_quranStreakBest", streak(for: \.quran)),
            ("dailyTasks_nawafilStreakBest", nawafilStreak()),
        ]
        for (bestKey, current) in currents where current > 0 {
            let best = max(defaults.integer(forKey: bestKey), current)
            if best > defaults.integer(forKey: bestKey) {
                defaults.set(best, forKey: bestKey)
            }
        }
        // Mirror the current values under the original's key names so other
        // surfaces (widgets/stats) can read them.
        defaults.set(streak(for: \.prayers), forKey: "dailyTasks_currentStreak")
        defaults.set(athkarStreak(), forKey: "dailyTasks_athkarStreakCurrent")
        defaults.set(streak(for: \.quran), forKey: "dailyTasks_quranStreakCurrent")
        defaults.set(nawafilStreak(), forKey: "dailyTasks_nawafilStreakCurrent")
    }

    /// The stored best for a streak field; falls back to at least the current
    /// streak so a fresh install that never wrote a best still reports it.
    static func bestFor(field: KeyPath<DayCheckin, Bool>) -> Int {
        let storedKey: String
        if field == \.prayers {
            storedKey = "dailyTasks_bestStreak"
        } else if field == \.quran {
            storedKey = "dailyTasks_quranStreakBest"
        } else if field == \.nawafil {
            storedKey = "dailyTasks_nawafilStreakBest"
        } else {
            storedKey = "dailyTasks_athkarStreakBest"
        }
        let stored = UserDefaults.standard.integer(forKey: storedKey)
        let current = streak(for: field)
        return max(stored, current)
    }

    static func athkarBest() -> Int {
        max(UserDefaults.standard.integer(forKey: "dailyTasks_athkarStreakBest"), athkarStreak())
    }

    private static func key(_ date: Date) -> String {
        makeKeyFormatter().string(from: date)
    }
}
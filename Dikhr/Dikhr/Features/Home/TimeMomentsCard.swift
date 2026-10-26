import SwiftUI

// MARK: - Time moments card
//
// Original ground truth: TimeMoments.json (bundle root) is a rule engine that
// drives the original's Time card / header widget — 42 rules anchoring content
// (athkar, salawat, friday, duha, qiyam, fasting days, ramadan) to prayer-time
// anchors with weekday lists, conditions and priorities. It is bundled here as
// Dikhr/Resources/home_timemoments.json.
//
// Rule shape: { id, title{ar,en}, detail{ar,en}, icon, start{anchor,offset},
// end{anchor,offset,cap}, priority, destination, group, days[0=Sun..6=Sat],
// enabled, condition, activeLabel }. Anchors: fajr/sunrise/dhuhr/asr/maghrib/
// isha/nextFajr/iqama0..4/nightMiddle/lastThird/clockMidnight; offsets in
// minutes; `cap` clamps the end to another anchor.

struct HomeMoment: Identifiable, Codable, Equatable {
    let id: String
    let title: [String: String]
    let detail: [String: String]
    let icon: String
    let start: MomentAnchor
    let end: MomentAnchor
    let priority: Int
    let destination: String
    let group: String
    let days: [Int]
    let enabled: Bool
    let condition: String?
    let activeLabel: [String: String]?

    struct MomentAnchor: Codable, Equatable {
        let anchor: String
        let offset: Int
        let cap: String?
    }

    var arabicTitle: String { title["ar"] ?? title["en"] ?? "" }
    var arabicDetail: String { detail["ar"] ?? detail["en"] ?? "" }
    var arabicActiveLabel: String? {
        guard let label = activeLabel else { return nil }
        return label["ar"] ?? label["en"]
    }
}

extension HomeMoment {
    /// English side for the language switch; falls back to the Arabic rule
    /// text when the bundled rule carries no "en" copy.
    var englishTitle: String { title["en"] ?? arabicTitle }
    var englishDetail: String { detail["en"] ?? arabicDetail }
    var englishActiveLabel: String? {
        guard let label = activeLabel else { return nil }
        return label["en"] ?? arabicActiveLabel
    }
}

enum HomeMomentEngine {
    static let rulesResource = ("home_timemoments", "json")

    // Anchor offsets (from TimeMoments.json itself):
    //  - rule "duha": sunrise + 20 min → dhuhr − 10 min
    //  - rule "quranAfternoon": iqama1 + 40 → asr
    //  - rule "sleep"/"ramadanSuhoor": isha/nextFajr ± 60
    // Iqama anchors are approximated with a 10-minute delay after the adhan
    // (the original has a configurable iqama offset setting).
    static let iqamaDelayMinutes = 10
    static let duhaStartAfterSunriseMinutes = 20
    static let duhaEndBeforeDhuhrMinutes = 10

    static func loadRules() -> [HomeMoment] {
        guard let url = Bundle.main.url(
            forResource: rulesResource.0, withExtension: rulesResource.1),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = dict["rules"] as? [[String: Any]],
              let data2 = try? JSONSerialization.data(withJSONObject: list),
              let rules = try? JSONDecoder().decode([HomeMoment].self, from: data2)
        else { return [] }
        return rules
    }

    private static var cachedRules: [HomeMoment]?

    static func rules() -> [HomeMoment] {
        if let cached = cachedRules { return cached }
        let loaded = loadRules()
        cachedRules = loaded
        return loaded
    }

    /// Resolves every anchor used by the rules. `times` may be nil (returns
    /// empty map, cards degrade gracefully).
    static func anchorDates(now: Date, times: PrayerTimes?,
                            method: PrayerMethod? = nil,
                            lat: Double, lng: Double,
                            timeZone: TimeZone = .current) -> [String: Date] {
        var anchors: [String: Date] = ["clockMidnight": Calendar.current.startOfDay(for: now)]
        guard let t = times else { return anchors }
        anchors["fajr"] = t.fajr
        anchors["sunrise"] = t.sunrise
        anchors["dhuhr"] = t.dhuhr
        anchors["asr"] = t.asr
        anchors["maghrib"] = t.maghrib
        anchors["isha"] = t.isha
        let delay = TimeInterval(iqamaDelayMinutes * 60)
        anchors["iqama0"] = t.fajr.addingTimeInterval(delay)
        anchors["iqama1"] = t.dhuhr.addingTimeInterval(delay)
        anchors["iqama2"] = t.asr.addingTimeInterval(delay)
        anchors["iqama3"] = t.maghrib.addingTimeInterval(delay)
        anchors["iqama4"] = t.isha.addingTimeInterval(delay)
        // nextFajr: today's fajr if still upcoming, else tomorrow's (recomputed
        // for accuracy when a method is available).
        var nextFajr = t.fajr > now ? t.fajr : t.fajr.addingTimeInterval(86_400)
        if t.fajr <= now, let method {
            let tomorrowTimes = PrayerTimesEngine.calculate(
                method: method, lat: lat, lng: lng,
                date: now.addingTimeInterval(86_400), timeZone: timeZone)
            nextFajr = tomorrowTimes.fajr
        }
        anchors["nextFajr"] = nextFajr
        // Night anchors: midpoint between maghrib and nextFajr, and the
        // engine's last-third (qiyam) time.
        let maghribBase = t.maghrib > now ? t.maghrib : t.maghrib.addingTimeInterval(-86_400)
        anchors["nightMiddle"] = maghribBase.addingTimeInterval(nextFajr.timeIntervalSince(maghribBase) / 2)
        anchors["lastThird"] = t.qiyamStart
        return anchors
    }

    static func resolveDate(_ anchor: HomeMoment.MomentAnchor, dates: [String: Date]) -> Date {
        let base = dates[anchor.anchor] ?? .distantPast
        return base.addingTimeInterval(Double(anchor.offset) * 60)
    }

    /// Condition keys from TimeMoments.json, evaluated against the hijri
    /// calendar (same adjustment as the date card).
    static func conditionMet(_ name: String?, now: Date, adjustment: Int) -> Bool {
        guard let name, !name.isEmpty else { return true }
        let c = Calendar.current.dateComponents([.weekday], from: now)
        let weekday = (c.weekday ?? 1) - 1 // 0=Sunday
        let today = HomeHijri.components(for: now, adjustment: adjustment)
        let tomorrow = HomeHijri.components(
            for: now.addingTimeInterval(86_400), adjustment: adjustment)
        let tomorrowIsRamadanStart = tomorrow.month == 9 && tomorrow.day == 1
        func whiteDay(_ c: (m: Int, d: Int)) -> Bool { [13, 14, 15].contains(c.d) }
        switch name {
        case "ramadanToday": return today.month == 9
        case "ramadanTomorrow": return tomorrowIsRamadanStart
        case "mondayToday": return weekday == 1
        case "mondayTomorrow": return weekday == 0      // today Sunday → tomorrow Monday
        case "thursdayToday": return weekday == 4
        case "thursdayTomorrow": return weekday == 3    // today Wednesday
        case "whiteDaysToday": return whiteDay((today.month, today.day))
        case "whiteDaysTomorrow": return whiteDay((tomorrow.month, tomorrow.day))
        case "arafahToday": return today.month == 12 && today.day == 9
        case "arafahTomorrow": return tomorrow.month == 12 && tomorrow.day == 9
        case "ashuraToday": return today.month == 1 && today.day == 10
        case "ashuraTomorrow": return tomorrow.month == 1 && tomorrow.day == 10
        case "voluntaryFastTomorrow":
            return weekday == 0 || weekday == 3
                || whiteDay((tomorrow.month, tomorrow.day))
                || (tomorrow.month == 12 && tomorrow.day == 9)
                || (tomorrow.month == 1 && tomorrow.day == 10)
        default: return true
        }
    }

    /// Highest-priority rule whose window covers `now`.
    static func current(now: Date, times: PrayerTimes?, adjustment: Int,
                        method: PrayerMethod? = nil, lat: Double = 0, lng: Double = 0,
                        excludingDestinations: Set<String> = ["prayerTimes"]) -> HomeMoment? {
        let dates = anchorDates(now: now, times: times, method: method, lat: lat, lng: lng)
        var best: HomeMoment?
        for rule in rules() where rule.enabled && !excludingDestinations.contains(rule.destination) {
            let start = resolveDate(rule.start, dates: dates)
            var end = resolveDate(rule.end, dates: dates)
            if let cap = rule.end.cap {
                let endDate = resolveDate(.init(anchor: cap, offset: 0, cap: nil), dates: dates)
                end = min(end, endDate)
            }
            guard now >= start, now < end else { continue }
            // `days` applies to the weekday of the window's start instant.
            let startWeekday = (Calendar.current.component(.weekday, from: start) - 1) % 7
            guard rule.days.contains(startWeekday) else { continue }
            guard conditionMet(rule.condition, now: now, adjustment: adjustment) else { continue }
            if best == nil || rule.priority > best!.priority { best = rule }
        }
        return best
    }
}

struct TimeMomentsCard: View {
    @EnvironmentObject private var settings: SettingsStore
    /// Optional integration hook: the rule's `destination` string
    /// (morning/evening/sleep/friday/quran/…). Not wired by this file.
    var onOpen: ((String) -> Void)? = nil
    var excludingDestinations: Set<String> = ["prayerTimes"]
    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var moment: HomeMoment? {
        let method = HomeCards.resolveMethod(settings: settings)
        return HomeMomentEngine.current(
            now: now,
            times: method.map {
                PrayerTimesEngine.calculate(method: $0, lat: settings.currentCity.lat,
                                            lng: settings.currentCity.lng, date: now,
                                            timeZone: .current)
            },
            adjustment: settings.hijriAdjustment,
            method: method, lat: settings.currentCity.lat, lng: settings.currentCity.lng,
            excludingDestinations: excludingDestinations)
    }

    var body: some View {
        Group {
            if let m = moment {
                card(m)
            } else {
                EmptyView()
            }
        }
        .onReceive(timer) { now = $0 }
        .dikhrRefresh(now: $now)
    }

    @ViewBuilder
    private func card(_ m: HomeMoment) -> some View {
        let body = HStack(spacing: 12) {
            Image(systemName: m.icon)
                .font(.title2)
                .foregroundStyle(.accent)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(.accent.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: settings.t(m.arabicTitle, m.englishTitle))
                    .font(.headline)
                let detail = settings.t(m.arabicDetail, m.englishDetail)
                if !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            let badge = settings.t(m.arabicActiveLabel ?? "", m.englishActiveLabel ?? "")
            if !badge.isEmpty {
                Text(verbatim: badge)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.accent.opacity(0.15)))
                    .foregroundStyle(.accent)
            }
        }
        if let onOpen {
            Button { onOpen(m.destination) } label: { body }
                .buttonStyle(.plain)
        } else {
            body
        }
    }
}
import SwiftUI

// MARK: - Shared support for the home cards
//
// Ground truth extracted from the original Athkar bundle:
//   - en.lproj/ar.lproj Localizable.strings (converted via plutil -convert json)
//   - TimeMoments.json / Ayaat.json (bundle root)
//   - Reviews.json (in-app review testimonials only, not used by these cards)

extension Notification.Name {
    /// Refresh signal posted whenever data/settings change (optional integration hook).
    static let dikhrRefresh = Notification.Name("dikhr-refresh")
}

enum HomeCards {
    /// The active prayer method (nil when not yet set up).
    static func resolveMethod(settings: SettingsStore) -> PrayerMethod? {
        SettingsStore.loadMethods().first(where: { $0.id == settings.methodID })
    }

    /// Prayer times for the current settings (mirrors HomeView's own lookup).
    static func resolveTimes(settings: SettingsStore, now: Date) -> PrayerTimes? {
        guard let method = resolveMethod(settings: settings) else { return nil }
        return PrayerTimesEngine.calculate(
            method: method, lat: settings.currentCity.lat, lng: settings.currentCity.lng,
            date: now, timeZone: .current)
    }

    private static let arabicNumberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.locale = Locale(identifier: "ar_SA") // Arabic-Indic digits (١٤٤٧)
        return f
    }()

    static func arabicDigits(_ value: Int) -> String {
        arabicNumberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Plain western digits for the English mode.
    static func englishDigits(_ value: Int) -> String { String(value) }

    /// Arabic day-count template from the original stringsdict:
    /// "%lld يوم" (1, 11+) / "%lld أيام" (3–10), with the dual forms for 1–2.
    static func arabicDays(_ n: Int) -> String {
        switch n {
        case 1: return "يوم واحد"
        case 2: return "يومان"
        case 3...10: return "\(arabicDigits(n)) أيام"
        default: return "\(arabicDigits(n)) يوم"
        }
    }

    /// English day-count counterpart of `arabicDays`.
    static func englishDays(_ n: Int) -> String {
        n == 1 ? "1 day" : "\(n) days"
    }
}

// MARK: - Hijri date helpers (Umm al-Qura + settings adjustment)

enum HomeHijri {
    private static var calendar: Calendar {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.locale = Locale(identifier: "ar_SA")
        return c
    }

    static let weekdays = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء",
                           "الخميس", "الجمعة", "السبت"]

    static let months = ["محرم", "صفر", "ربيع الأول", "ربيع الآخر",
                         "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان",
                         "رمضان", "شوال", "ذو القعدة", "ذو الحجة"]

    struct Components {
        let year: Int
        let month: Int
        let day: Int
        /// Real-world weekday index (0 = الأحد), unaffected by the adjustment.
        let weekday: Int
    }

    /// Hijri components with the settings offset applied to the hijri date only
    /// (same semantics as the original's RemoteConfig hijriDateAdjustment and
    /// Dikhr's "تعديل التاريخ الهجري" setting: whole calendar-day offset).
    static func components(for date: Date, adjustment: Int) -> Components {
        let c = calendar
        let ymd = c.dateComponents([.year, .month, .day], from: date)
        let hijriDayStart = c.date(from: DateComponents(year: ymd.year ?? 1400,
                                                        month: ymd.month ?? 1,
                                                        day: ymd.day ?? 1)) ?? date
        let shifted = c.date(byAdding: .day, value: adjustment, to: hijriDayStart) ?? date
        let comp = c.dateComponents([.year, .month, .day], from: shifted)
        let weekdayIdx = (Calendar.current.component(.weekday, from: date) - 1)
        return Components(year: comp.year ?? 0,
                          month: comp.month ?? 1,
                          day: comp.day ?? 1,
                          weekday: weekdayIdx % weekdays.count)
    }

    /// Start of 1 Ramadan of the upcoming hijri year (as seen through the
    /// adjustment), plus the whole-day gap. Returns nil inside Ramadan.
    static func daysUntilRamadan(now: Date, adjustment: Int) -> (days: Int, target: Date, hijriYear: Int)? {
        let c = calendar
        let adjustedNow = now.addingTimeInterval(Double(adjustment) * 86_400)
        let today = c.dateComponents([.year, .month, .day], from: adjustedNow)
        guard today.month != 9 else { return nil }
        let targetYear = (today.month ?? 1) < 9 ? today.year ?? 0 : (today.year ?? 0) + 1
        guard let target = c.date(from: DateComponents(year: targetYear, month: 9, day: 1))
        else { return nil }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: adjustedNow),
            to: Calendar.current.startOfDay(for: target)).day ?? 0
        return (max(days, 0), target, targetYear)
    }

    static func isRamadan(now: Date, adjustment: Int) -> Bool {
        components(for: now, adjustment: adjustment).month == 9
    }

    /// "الجمعة ١٤ ربيع الأول ١٤٤٧ هـ" (heading style: day + hijri date).
    static func arabicLine(for date: Date, adjustment: Int) -> String {
        let c = components(for: date, adjustment: adjustment)
        guard c.month >= 1 && c.month <= 12 else { return "" }
        return "\(weekdays[c.weekday]) \(HomeCards.arabicDigits(c.day)) \(months[c.month - 1]) \(HomeCards.arabicDigits(c.year)) هـ"
    }

    /// English counterpart of `arabicLine`, e.g. "Friday 14 Rabi' al-Awwal 1447 AH".
    static func englishLine(for date: Date, adjustment: Int) -> String {
        let c = components(for: date, adjustment: adjustment)
        guard c.month >= 1 && c.month <= 12 else { return "" }
        let englishWeekdays = ["Sunday", "Monday", "Tuesday", "Wednesday",
                               "Thursday", "Friday", "Saturday"]
        let englishMonths = ["Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
                             "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
                             "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"]
        return "\(englishWeekdays[c.weekday]) \(englishMonths[c.month - 1]) \(c.day), \(c.year) AH"
    }

    /// Secondary gregorian line, e.g. "٢٥ أكتوبر ٢٠٢٦ م". The calendar must be
    /// forced to gregorian — CLDR's ar-SA default calendar is islamic.
    static func gregorianLine(for date: Date) -> String {
        let en = DikhrStrings.lang == .english
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: en ? "en_US" : "ar_SA")
        f.timeZone = .current
        f.dateStyle = .long
        f.timeStyle = .none
        return "\(f.string(from: date)) م"
    }
}

// MARK: - Refresh helper

extension View {
    /// Re-derives `now` when the "dikhr-refresh" notification is posted.
    func dikhrRefresh(now: Binding<Date>) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .dikhrRefresh)) { _ in
            now.wrappedValue = Date()
        }
    }
}
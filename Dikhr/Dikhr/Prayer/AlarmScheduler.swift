import Foundation
import UserNotifications

/// Per-prayer alarm configuration (mirrors the original's at-athan /
/// minutes-before / minutes-after offsets plus an iqama reminder).
struct PrayerAlarmConfig: Codable, Identifiable, Hashable {
    var prayer: String
    var enabled: Bool = false
    var mode: Mode = .atAthan
    var offsetMinutes: Int = 0
    var iqamaEnabled: Bool = false
    var iqamaMinutes: Int = 15

    enum Mode: String, Codable, CaseIterable, Identifiable {
        case atAthan
        case before
        case after
        var id: String { rawValue }
        var arabic: String {
            switch self {
            case .atAthan: return "عند الأذان"
            case .before: return "قبل الأذان"
            case .after: return "بعد الأذان"
            }
        }
    }

    var id: String { prayer }
}

/// Schedules silent-mode-independent notifications for the coming days.
enum AlarmScheduler {
    private static let daysAhead = 7

    static func loadConfigs() -> [PrayerAlarmConfig] {
        let defaultOrder = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]
        guard let data = UserDefaults.standard.data(forKey: "prayerAlarms"),
              let saved = try? JSONDecoder().decode([PrayerAlarmConfig].self, from: data)
        else { return defaultOrder.map { PrayerAlarmConfig(prayer: $0) } }
        // Keep canonical order and add any missing prayers
        var byID = Dictionary(uniqueKeysWithValues: saved.map { ($0.prayer, $0) })
        return defaultOrder.map { byID.removeValue(forKey: $0) ?? PrayerAlarmConfig(prayer: $0) }
    }

    static func save(_ configs: [PrayerAlarmConfig]) {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: "prayerAlarms")
        }
    }

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
                granted, _ in
                cont.resume(returning: granted)
            }
        }
    }

    static func rescheduleAll(configs: [PrayerAlarmConfig], method: PrayerMethod, city: City) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let active = configs.filter(\.enabled)
        guard !active.isEmpty else { return }
        if await !requestAuthorization() { return }

        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        var scheduled = 0

        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            let times = PrayerTimesEngine.calculate(
                method: method, lat: city.lat, lng: city.lng, date: day, timeZone: .current)
            let map: [(String, Date)] = [
                ("fajr", times.fajr), ("sunrise", times.sunrise), ("dhuhr", times.dhuhr),
                ("asr", times.asr), ("maghrib", times.maghrib), ("isha", times.isha)]
            for config in active {
                guard let (_, prayerDate) = map.first(where: { $0.0 == config.prayer }) else { continue }
                let label = kindLabel(config.prayer)
                let fire = fireDate(config: config, prayerDate: prayerDate)
                guard fire > now else { continue }
                scheduleOne(center: center, config: config, fire: fire, label: label)
                if config.iqamaEnabled, config.prayer != "sunrise" {
                    let iqamaFire = fireDate(config: config, prayerDate: prayerDate)
                        .addingTimeInterval(Double(config.iqamaMinutes) * 60)
                    let iqamaConfig = PrayerAlarmConfig(
                        prayer: config.prayer, enabled: true, mode: .after,
                        offsetMinutes: config.iqamaMinutes,
                        iqamaEnabled: true, iqamaMinutes: config.iqamaMinutes)
                    if iqamaFire > now {
                        scheduleIqama(center: center, config: iqamaConfig, fire: iqamaFire, label: label)
                    }
                }
                scheduled += 1
            }
        }
    }

    private static func fireDate(config: PrayerAlarmConfig, prayerDate: Date) -> Date {
        switch config.mode {
        case .atAthan: return prayerDate
        case .before: return prayerDate.addingTimeInterval(-Double(config.offsetMinutes) * 60)
        case .after: return prayerDate.addingTimeInterval(Double(config.offsetMinutes) * 60)
        }
    }

    private static func scheduleOne(center: UNUserNotificationCenter, config: PrayerAlarmConfig, fire: Date, label: String) {
        let content = UNMutableNotificationContent()
        content.title = "أذان \(label)"
        let offsetText: String
        switch config.mode {
        case .atAthan: offsetText = "الآن وقت صلاة \(label)"
        case .before: offsetText = "باقي \(config.offsetMinutes) دقيقة على أذان \(label)"
        case .after: offsetText = "مضى على أذان \(label) \(config.offsetMinutes) دقيقة"
        }
        content.body = offsetText
        content.sound = notificationSound(for: config.prayer)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components(of: fire), repeats: false)
        let request = UNNotificationRequest(
            identifier: "alarm-\(config.prayer)-\(key(of: fire))",
            content: content, trigger: trigger)
        center.add(request)
    }

    private static func scheduleIqama(center: UNUserNotificationCenter, config: PrayerAlarmConfig, fire: Date, label: String) {
        let content = UNMutableNotificationContent()
        content.title = "الإقامة"
        content.body = "باقي \(config.iqamaMinutes) دقيقة على إقامة صلاة \(label)"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components(of: fire), repeats: false)
        let request = UNNotificationRequest(
            identifier: "iqama-\(config.prayer)-\(key(of: fire))",
            content: content, trigger: trigger)
        center.add(request)
    }

    /// UNNotificationSound for the per-prayer selection.
    private static func notificationSound(for prayer: String) -> UNNotificationSound? {
        switch AthanSoundStore.selected(for: prayer) {
        case .defaultSystem: return .default
        case .silent: return nil
        case .bundled, .imported:
            let sound = AthanSoundStore.selected(for: prayer)
            guard sound.notificationSafe,
                  AthanSoundStore.stageForNotifications(sound) != nil,
                  let file = sound.fileBaseName else { return .default }
            return UNNotificationSound(named: UNNotificationSoundName(file))
        }
    }

    private static func components(of date: Date) -> DateComponents {
        var c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        c.second = 0
        return c
    }

    private static func key(of date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: date)
    }

    private static func kindLabel(_ prayer: String) -> String {
        switch prayer {
        case "fajr": return "الفجر"
        case "sunrise": return "الشروق"
        case "dhuhr": return "الظهر"
        case "asr": return "العصر"
        case "maghrib": return "المغرب"
        case "isha": return "العشاء"
        default: return prayer
        }
    }
}
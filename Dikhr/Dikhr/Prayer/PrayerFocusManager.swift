import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

/// Prayer Focus (عُفص الصلاة): schedules DeviceActivity windows around each
/// prayer and shields third-party apps during them (matching the original's
/// PrayerFocusMonitor/Action/Shield extensions).
@MainActor
final class PrayerFocusManager: ObservableObject {
    static var shared = PrayerFocusManager()

    @Published var authorized = false
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "prayerFocusEnabled")
            Task { await applySchedule() }
        }
    }

    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("prayerFocus"))

    private init() {
        enabled = UserDefaults.standard.bool(forKey: "prayerFocusEnabled")
        authorized = AuthorizationStatus(rawValue: UserDefaults.standard.integer(forKey: "prayerFocusAuth")) == .approved
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            updateAuth()
        } catch {
            enabled = false
        }
    }

    private func updateAuth() {
        Task { @MainActor in
            let status = AuthorizationCenter.shared.authorizationStatus
            authorized = status == .approved
            UserDefaults.standard.set(status.rawValue, forKey: "prayerFocusAuth")
        }
    }

    /// Schedules one DeviceActivity window per prayer: 5 min before athan to 20 min after.
    func applySchedule() async {
        guard enabled, authorized else {
            endShield()
            return
        }
        center.stopMonitoring()
        let configs = AlarmScheduler.loadConfigs()
        let city = DikhrShared.city
        let method = DikhrMethodLoader.method(id: DikhrShared.methodID)
        let calendar = Calendar.current
        let schedule: [(String, DeviceActivitySchedule)] = {
            var list: [(String, DeviceActivitySchedule)] = []
            for days in [0, 1] {
                let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: Date()))!
                let times = PrayerTimesEngine.calculate(method: method, lat: city.lat, lng: city.lng, date: day, timeZone: .current)
                for pair in [("fajr", times.fajr), ("dhuhr", times.dhuhr), ("asr", times.asr), ("maghrib", times.maghrib), ("isha", times.isha)] {
                    let start = pair.1.addingTimeInterval(-5 * 60)
                    let end = pair.1.addingTimeInterval(20 * 60)
                    if end <= start { continue }
                    let comps = calendar.dateComponents([.hour, .minute], from: start)
                    let endComps = calendar.dateComponents([.hour, .minute], from: end)
                    list.append(("dikhrFocus-\(pair.0)-\(days)", DeviceActivitySchedule(
                        intervalStart: comps, intervalEnd: endComps,
                        repeats: false, warningTime: nil)))
                }
            }
            return list
        }()
        for (name, window) in schedule {
            try? center.startMonitoring(DeviceActivityName(name), during: window)
        }
    }

    func endShield() {
        store.shield.applicationCategories = nil
        store.shield.applications = nil
    }
}
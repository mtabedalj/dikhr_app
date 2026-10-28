import Foundation
import UserNotifications
import WatchConnectivity

/// Watch-side receiver for the phone bridge. Mirrors the original app:
/// the iPhone pushes athkar sections (with a pushed-hash guard) and the
/// counter list; the watch reports counter taps back. Also routes
/// prayer-time alerts to the watch as local notifications.
final class WatchSessionReceiver: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchSessionReceiver()

    @Published var city = DikhrShared.city
    @Published var methodID = DikhrShared.methodID

    private let nc = NotificationCenter.default

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Decoding

    private func decode<T: Decodable>(_ type: T.Type, _ raw: Any?) -> T? {
        guard let data = raw as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func storeSections(_ data: Data) {
        guard let list = try? JSONDecoder().decode([AthkarSectionPlain].self, from: data) else { return }
        DikhrShared.saveWatchAthkarSections(list)
        nc.post(name: .watchSectionsChanged, object: nil)
    }

    private func storeCounters(_ data: Data) {
        guard let list = try? JSONDecoder().decode([SavedCounter].self, from: data) else { return }
        DikhrShared.saveCounters(list)
        nc.post(name: .watchCountersChanged, object: nil)
    }

    private func storePayload(_ context: [String: Any]) {
        if let sections = decode([AthkarSectionPlain].self, context[WatchSyncKeys.athkarSections]) {
            if let data = try? JSONEncoder().encode(sections) { storeSections(data) }
        }
        if let counters = decode([SavedCounter].self, context[WatchSyncKeys.counters]) {
            storeCounters((try? JSONEncoder().encode(counters)) ?? Data())
        }
        if let city = decode(City.self, context[WatchSyncKeys.city]) {
            DikhrShared.saveCity(city)
            self.city = city
        }
        if let methodID = context[WatchSyncKeys.method] as? String {
            DikhrShared.methodID = methodID
            self.methodID = methodID
        }
        rescheduleAlerts()
    }

    // MARK: - Prayer alerts on the watch (original routes the athan/alert here)

    private var alertScheduled = false

    private func rescheduleAlerts() {
        guard !alertScheduled else { return }
        alertScheduled = true
        let city = DikhrShared.city
        let method = DikhrMethodLoader.method(id: DikhrShared.methodID)
        let times = PrayerTimesEngine.calculate(method: method, lat: city.lat, lng: city.lng,
                                                date: Date(), timeZone: .current)

        let center = UNUserNotificationCenter.current()
        let names = ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"]
        let dates = [times.fajr, times.sunrise, times.dhuhr, times.asr, times.maghrib, times.isha]

        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        center.removeAllPendingNotificationRequests()

        for (name, date) in zip(names, dates) where date > Date() {
            let content = UNMutableNotificationContent()
            content.title = "أذكار — \(name)"
            content.body = "الآن موعد صلاة \(name)"
            content.sound = UNNotificationSound.default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
            let request = UNNotificationRequest(identifier: "watch.prayer.\(name)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated, !session.receivedApplicationContext.isEmpty {
            storePayload(session.receivedApplicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.storePayload(applicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.storePayload(message)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            // Ask the phone for a fresh push (original re-enters the watch app
            // after updating prayer times on the iPhone).
            try? session.updateApplicationContext([WatchSyncKeys.requestRefresh: true])
        }
    }
}

extension WatchSessionReceiver {
    /// Watch → phone: report counter state after each tap.
    func sendCounterUpdate(_ counters: [SavedCounter]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard let data = try? JSONEncoder().encode(counters), session.isReachable else { return }
        if session.activationState == .activated {
            session.sendMessage([WatchSyncKeys.counterUpdate: data], replyHandler: nil)
        }
    }
}
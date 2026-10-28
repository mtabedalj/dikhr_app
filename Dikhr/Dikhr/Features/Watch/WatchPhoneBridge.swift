import Foundation
import WatchConnectivity

/// iPhone-side bridge to the DikhrWatch companion. Reproduces the original
/// Athkar watch flow: sections toggled "استخدم في الساعة" are pushed to the
/// watch over WatchConnectivity, skipped when nothing changed (the original
/// keeps a `watchMyAthkarPushedHash`), and the phone also mirrors them into
/// the shared app group for the app-group-entitled targets.
///
/// Wiring request: call `WatchPhoneBridge.shared.activate()` once from the
/// app entry (e.g. DikhrApp.init or onAppear) — that hook is owned by main.
final class WatchPhoneBridge: NSObject, WCSessionDelegate {
    static let shared = WatchPhoneBridge()

    override private init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Build & push

    private func currentSections() -> [AthkarSectionPlain] {
        let categories = AthkarStore.loadCategories()
        let pairs = categories.map { (id: $0.id, title: $0.title, entries: $0.entries) }
        let sections = WatchAthkarSync.sections(from: pairs, enabled: DikhrShared.watchSectionIDs)
        return sections
    }

    /// Pushes athkar sections, counters, city and method. Returns true when
    /// anything was sent (hash changed).
    @discardableResult
    func push() -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        guard session.activationState == .activated else { return false }

        let sections = currentSections()
        let hash = WatchAthkarSync.fingerprint(sections)
        guard hash != DikhrShared.watchPushedHash else { return false }

        var context: [String: Any] = [
            WatchSyncKeys.pushedHash: hash,
        ]
        if let data = try? JSONEncoder().encode(sections) {
            context[WatchSyncKeys.athkarSections] = data
            DikhrShared.saveWatchAthkarSections(sections)
        }
        if let data = try? JSONEncoder().encode(DikhrShared.loadCounters()) {
            context[WatchSyncKeys.counters] = data
        }
        if let city = DikhrShared.loadCity(), let data = try? JSONEncoder().encode(city) {
            context[WatchSyncKeys.city] = data
        }
        context[WatchSyncKeys.method] = DikhrShared.methodID

        try? session.updateApplicationContext(context)
        DikhrShared.setWatchPushedHash(hash)
        return true
    }

    /// Called after the user toggles a section — recomputes and pushes.
    func sectionTogglesChanged() {
        push()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        guard activationState == .activated else { return }
        DispatchQueue.main.async { self.push() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            DispatchQueue.main.async { self.push() }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let data = message[WatchSyncKeys.counterUpdate] as? Data,
           let counters = try? JSONDecoder().decode([SavedCounter].self, from: data) {
            DispatchQueue.main.async {
                DikhrShared.saveCounters(counters)
            }
        } else if message[WatchSyncKeys.requestRefresh] != nil {
            DispatchQueue.main.async {
                // Force a fresh push (drop the hash guard once).
                DikhrShared.setWatchPushedHash("")
                self.push()
            }
        }
    }
}
import Foundation
import DeviceActivity
import ManagedSettings

/// Applies/relaxes the application shield on prayer-focus interval boundaries,
/// mirroring the original's PrayerFocusMonitor extension.
class PrayerFocusMonitorExtension: DeviceActivityMonitor {
    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("prayerFocus"))

    override func intervalDidStart(for activity: DeviceActivityName) {
        store.shield.applicationCategories = .all()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}
import SwiftUI
import WatchKit

/// Watch companion entry. Screens mirror the original Athkar watch app:
/// مواقيت الصلاة · الأذكار (sections pushed from the iPhone as plain text) · العدّاد.
/// The original's watch accent (from its Assets.car) is a light sky blue.
@main
struct DikhrWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .onAppear { WatchSessionReceiver.shared.activate() }
        }
    }
}

/// App delegate for watch lifecycle — activates the phone bridge early so a
/// push that woke the app is handled before the UI appears.
final class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidBecomeActive() {
        WatchSessionReceiver.shared.activate()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// The original watch bundle's AccentColor (assetutil: 0.462, 0.838, 1.0) = #76D6FF.
enum WatchTheme {
    static let accent = Color(red: 0.462, green: 0.838, blue: 1.0)
    /// The original reserve green for prayer times rows (Dikhr's own convention).
    static let prayerGreen = Color(red: 0.0, green: 0.58, blue: 0.416)

    static func athkarText(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .medium)
    }
}

extension Notification.Name {
    /// Fired by WatchSessionReceiver when synced data changes from the phone.
    static let watchCountersChanged = Notification.Name("watch.countersChanged")
    static let watchSectionsChanged = Notification.Name("watch.sectionsChanged")
}

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchPrayerTimesView()
            WatchAthkarView()
            WatchCounterView()
        }
        .tabViewStyle(.page)
        // The original is Arabic-first on the watch (CFBundleDevelopmentRegion = ar).
        .environment(\.layoutDirection, .rightToLeft)
        .tint(WatchTheme.accent)
    }
}

/// Watch haptics helper.
enum WKInterfaceHelper {
    static func haptic(_ style: WKHapticType) {
        WKInterfaceDevice.current().play(style)
    }
}
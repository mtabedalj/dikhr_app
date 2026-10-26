import Foundation
import os

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

/// Firebase wiring (Analytics, Crashlytics, Messaging, RemoteConfig).
/// Everything compiles even when the package fails to resolve: guarded with
/// canImport so a missing dependency degrades to a no-op. Configure is skipped
/// unless a real GoogleService-Info.plist is bundled — create your own project
/// at console.firebase.google.com and drop the downloaded plist next to
/// DikhrInfo.plist (never reuse another app's config).
enum FirebaseBootstrap {
    private static let log = Logger(subsystem: "dev.dikhr", category: "firebase")
    private(set) static var isConfigured = false

    static func configure() {
        guard let plistURL = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: plistURL),
              let config = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let apiKey = config["API_KEY"] as? String,
              !apiKey.isEmpty, !apiKey.contains("REPLACE")
        else {
            log.info("Firebase: GoogleService-Info.plist missing or placeholder — skipping configuration")
            return
        }
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        isConfigured = true
        let projectID = String(describing: config["PROJECT_ID"] ?? "?")
        log.info("Firebase configured (project: \(projectID))")
        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(true)
        #endif
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
        #else
        log.info("Firebase SDK not resolved — features disabled")
        #endif
    }
}

// MARK: - Analytics events

enum AnalyticsService {
    static func screen(_ name: String) {
        #if canImport(FirebaseAnalytics)
        guard FirebaseBootstrap.isConfigured else { return }
        Analytics.logEvent(AnalyticsEventScreenView,
                           parameters: [AnalyticsParameterScreenName: name])
        #endif
    }

    static func event(_ name: String, _ params: [String: Any] = [:]) {
        #if canImport(FirebaseAnalytics)
        guard FirebaseBootstrap.isConfigured else { return }
        Analytics.logEvent(name, parameters: params)
        #endif
    }
}

// MARK: - Remote Config (news feed)

enum RemoteConfigService {
    static func fetchAndActivateNews() async {
        #if canImport(FirebaseRemoteConfig)
        guard FirebaseBootstrap.isConfigured else { return }
        let remote = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        remote.configSettings = settings
        do {
            _ = try await remote.fetchAndActivate()
            let version = remote["dikhrNewsVersion"].numberValue.intValue
            let payload = remote["dikhrNews"].stringValue
            if let data = payload.data(using: .utf8),
               let items = try? JSONDecoder().decode([NewsItem].self, from: data) {
                await MainActor.run {
                    NewsStore.shared.applyRemoteVersion(String(version), items: items)
                }
            }
        } catch {
            Logger(subsystem: "dev.dikhr", category: "firebase")
                .info("RemoteConfig fetch failed: \(error.localizedDescription)")
        }
        #endif
    }
}

// MARK: - Messaging (push; full delivery needs a device + APNs entitlement)

#if canImport(FirebaseMessaging)
final class FirebaseMessagingDelegate: NSObject, MessagingDelegate {
    static let shared = FirebaseMessagingDelegate()

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Logger(subsystem: "dev.dikhr", category: "firebase")
            .info("FCM token refreshed: \(fcmToken?.prefix(8) ?? "-")…")
    }
}
#endif

enum MessagingService {
    static func register() async {
        #if canImport(FirebaseMessaging)
        guard FirebaseBootstrap.isConfigured else { return }
        Messaging.messaging().delegate = FirebaseMessagingDelegate.shared
        #endif
    }
}
import Foundation
import SwiftUI
import UIKit

// MARK: - Deep links + quick actions (app side)
//
// URL scheme "dikhr" (wiring note: CFBundleURLTypes "dikhr" in DikhrInfo.plist):
//   dikhr://tab/counter     → counter tab
//   dikhr://tab/athkar      → athkar tab
//   dikhr://tab/prayer      → home (prayer times) tab
//   dikhr://tab/settings    → settings tab
//   dikhr://action/randomAthkar → random athkar (athkar tab + action)
//
// Quick actions — the original's UIApplicationShortcutItems (wiring note: add
// these to DikhrInfo.plist, then call QuickActions.register() from DikhrApp):
//   counter / randomAthkar / prayerTimes / myAthkar

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    /// Tab identifier ready to be consumed by RootTabView
    /// (values match its tags: home / athkar / counter / quran / settings).
    @Published var pendingTab: String?
    /// Quick action the selected tab should consume:
    /// "randomAthkar" or "myAthkar".
    @Published var pendingAction: String?

    // MARK: URL routing (onOpenURL → handle(url:))

    func handle(url: URL) {
        guard url.scheme?.lowercased() == "dikhr" else { return }
        switch url.host?.lowercased() {
        case "tab":
            pendingTab = Self.tabTag(for: url.pathComponents.dropFirst().first)
        case "action":
            let action = url.pathComponents.dropFirst().first?.lowercased()
            switch action {
            case "randomathkar":
                pendingTab = "athkar"
                pendingAction = "randomAthkar"
            case "myathkar":
                pendingTab = "athkar"
                pendingAction = "myAthkar"
            default:
                break
            }
        default:
            break
        }
    }

    static func tabTag(for raw: String?) -> String? {
        switch raw?.lowercased() {
        case "counter": return "counter"
        case "athkar": return "athkar"
        case "prayer", "home": return "home"
        case "quran": return "quran"
        case "settings": return "settings"
        default: return nil
        }
    }

    // MARK: Quick actions

    func handle(shortcutItem: UIApplicationShortcutItem) {
        let type = shortcutItem.type.lowercased()
        // Match either bare type names ("counter") or reverse-DNS ones
        // ("dev.dikhr.quick.counter") so any plist wiring works.
        let key = type.contains(".") ? type.components(separatedBy: ".").last ?? type : type
        switch key {
        case "counter":
            pendingTab = "counter"
        case "prayertimes":
            pendingTab = "home"
        case "randomathkar":
            pendingTab = "athkar"
            pendingAction = "randomAthkar"
        case "myathkar":
            pendingTab = "athkar"
            pendingAction = "myAthkar"
        default:
            break
        }
    }
}

// MARK: - Quick-action shortcuts

/// Original Info.plist UIApplicationShortcutItems:
/// العداد (stopwatch) / أذكار منوعة (book) / مواقيت الصلاة (clock) / أذكاري (text.badge.plus)
enum QuickActions {

    struct Shortcut {
        let type: String      // UIApplicationShortcutItemType
        let title: String     // localized display name (Arabic)
        let symbol: String    // system image name
        let subtitle: String? // optional
    }

    /// Reference list for the DikhrInfo.plist UIApplicationShortcutItems wiring
    /// (types expected by DeepLinkRouter.handle(shortcutItem:)).
    static let shortcuts: [Shortcut] = [
        Shortcut(type: "dev.dikhr.quick.counter", title: "العداد", symbol: "stopwatch", subtitle: nil),
        Shortcut(type: "dev.dikhr.quick.randomAthkar", title: "أذكار منوعة", symbol: "book", subtitle: nil),
        Shortcut(type: "dev.dikhr.quick.prayerTimes", title: "مواقيت الصلاة", symbol: "clock", subtitle: nil),
        Shortcut(type: "dev.dikhr.quick.myAthkar", title: "أذكاري", symbol: "text.badge.plus", subtitle: nil)
    ]

    private static var registered = false

    /// Call once from DikhrApp (e.g. init). Shortcuts launched cold arrive as
    /// UIApplication.shortcutItem right after activation; warm launches deliver
    /// the same. Consuming: RootTabView watches router.pendingTab/pendingAction.
    static func register() {
        guard !registered else { return }
        registered = true
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            consumePendingShortcut()
        }
    }

    static func consumePendingShortcut() {
        guard let shortcut = QuickActionsAppDelegate.pendingShortcut else { return }
        QuickActionsAppDelegate.pendingShortcut = nil
        Task { @MainActor in
            DeepLinkRouter.shared.handle(shortcutItem: shortcut)
        }
    }
}

/// Scene-delegate plumbing so home-screen quick actions (UIApplicationShortcutItem)
/// reach Dikhr under the SwiftUI app lifecycle.
import SwiftUI

final class QuickActionsAppDelegate: NSObject, UIApplicationDelegate {
    static var pendingShortcut: UIApplicationShortcutItem?

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            Self.pendingShortcut = shortcut
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionsSceneDelegate.self
        return configuration
    }
}

final class QuickActionsSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickActionsAppDelegate.pendingShortcut = shortcutItem
        completionHandler(true)
    }
}

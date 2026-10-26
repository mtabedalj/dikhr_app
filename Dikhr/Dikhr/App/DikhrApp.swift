import SwiftUI
import CoreText
import UIKit
import os

enum FontRegistration {
    static func registerBundledFonts() {
        for name in ["UthmanicHafs_V22_Bold.ttf", "Scheherazade-Regular.ttf"] {
            guard let url = Bundle.main.url(forResource: (name as NSString).deletingPathExtension,
                                            withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    static let quranUthmani = Font.custom("KFGQPCHAFSUthmanicScript-Bold", size: 26)
    static let quranMarker = Font.custom("KFGQPCHAFSUthmanicScript-Bold", size: 30)
    static let quranNaskh = Font.custom("Scheherazade-Regular", size: 24)
    static let athkarBody = Font.custom("Scheherazade-Regular", size: 21)
}

@main
struct DikhrApp: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var location = LocationController.shared
    @Environment(\.scenePhase) private var scenePhase

    @UIApplicationDelegateAdaptor(QuickActionsAppDelegate.self) private var appDelegate

    init() {
        if ProcessInfo.processInfo.environment["DIKHR_AUTODETECT"] != nil {
            UserDefaults.standard.set(true, forKey: "useAutoLocation")
        }
        if let forced = ProcessInfo.processInfo.environment["DIKHR_LANG"] {
            UserDefaults.standard.set(forced == "en" ? "english" : "arabic", forKey: "lang")
        }
        FontRegistration.registerBundledFonts()
        DikhrFontRegistration.register()
        QuickActions.register()
        FirebaseBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(settings)
                .onOpenURL { url in
                    DeepLinkRouter.shared.handle(url: url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                location.start()
                Task { await RemoteConfigService.fetchAndActivateNews() }
                Task { await MomentsScheduler.schedule() }
                Task { await DuhaNotificationController.shared.schedule() }
                Task { await MessagingService.register() }
                if settings.useAutoLocation, let c = location.fix {
                    settings.detectedCity = City(
                        name: c.cityName, lat: c.latitude,
                        lng: c.longitude, tag: c.tag, country: c.country)
                }
                if let picked = ProcessInfo.processInfo.environment["DIKHR_PICK_CITY"] {
                    let match = SettingsStore.loadCities().flatMap { $0.2 }
                        .first(where: { $0.name.contains(picked) || picked.contains($0.name) })
                    if let city = match {
                        settings.city = city
                        settings.useAutoLocation = false
                        Logger(subsystem: "dev.dikhr", category: "mushaf").info("picked city \(city.name) lat=\(city.lat)")
                    }
                }
                Task {
                    if let method = SettingsStore.loadMethods().first(where: { $0.id == settings.methodID }) {
                        await AlarmScheduler.rescheduleAll(
                            configs: AlarmScheduler.loadConfigs(),
                            method: method, city: settings.currentCity)
                    }
                }
            }
        }
        .onChange(of: location.fix) { _, value in
            guard settings.useAutoLocation, let c = value else { return }
            let city = City(name: c.cityName, lat: c.latitude, lng: c.longitude, tag: c.tag, country: c.country)
            settings.detectedCity = city
            Task {
                if let method = SettingsStore.loadMethods().first(where: { $0.id == settings.methodID }) {
                    await AlarmScheduler.rescheduleAll(
                        configs: AlarmScheduler.loadConfigs(),
                        method: method, city: city)
                }
            }
        }
    }
}

enum QuranPalette {
    static let paper = Color(light: Color(red: 0.968, green: 0.960, blue: 0.936),
                             dark: Color(red: 0.11, green: 0.106, blue: 0.094))
    static let darkGreen = Color(light: Color(red: 0.0, green: 0.58, blue: 0.42),
                                 dark: Color(red: 0.24, green: 0.78, blue: 0.62))
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

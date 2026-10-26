import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var router = DeepLinkRouter.shared
    @State private var selection = ProcessInfo.processInfo.environment["DIKHTML_TAB"] ?? ProcessInfo.processInfo.environment["DIKHR_TAB"] ?? "home"

    @Environment(\.requestReview) private var requestReview

    var body: some View {
        DikhrAdaptiveRoot(externalSelection: $selection) {
            tabViewRoot
        }
        .tint(settings.accentColor)
            .preferredColorScheme(settings.preferredColorScheme)
            .environment(\.layoutDirection, settings.lang == .arabic ? .rightToLeft : .leftToRight)
            .onAppear {
                Task { @MainActor in
                    ReviewService.maybePrompt(viewContext: requestReview)
                }
            }
            .onReceive(router.$pendingTab) { tab in
                if let tab { selection = tab; router.pendingTab = nil }
            }
            .onChange(of: selection) { _, tab in
                AnalyticsService.screen(tab)
            }
            .onReceive(router.$pendingAction) { action in
                if let action {
                    selection = "athkar"
                    router.pendingAction = nil
                }
            }
    }

    private var tabViewRoot: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label(settings.t("مواقيت الصلاة", "Prayer Times"), systemImage: "clock") }
                .tag("home")
            AthkarCategoryListView()
                .tabItem { Label(settings.t("أذكار", "Athkar"), systemImage: "book") }
                .tag("athkar")
            CounterView()
                .tabItem { Label(settings.t("العداد", "Counter"), systemImage: "stopwatch") }
                .tag("counter")
            QuranView()
                .tabItem { Label(settings.t("القرآن", "Quran"), systemImage: "text.book.closed") }
                .tag("quran")
            SettingsView()
                .tabItem { Label(settings.t("الإعدادات", "Settings"), systemImage: "gearshape") }
                .tag("settings")
        }
    }
}
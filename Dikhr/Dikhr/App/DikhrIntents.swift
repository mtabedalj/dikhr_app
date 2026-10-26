import Foundation
import AppIntents

// MARK: - Random Athkar

struct RandomAthkarIntent: AppIntent {
    static var title: LocalizedStringResource = "أذكار منوعة"
    static var description = IntentDescription("يعرض ذكرًا عشوائيًا من أذكار منوعة.")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let mix = AthkarStore.loadMix()
        guard let dhikr = mix.randomElement(), !dhikr.isEmpty else {
            return .result(dialog: "لا توجد أذكار")
        }
        return .result(dialog: IntentDialog(full: LocalizedStringResource(stringLiteral: dhikr), supporting: LocalizedStringResource(stringLiteral: "أذكار منوعة — dikhr")))
    }
}

// MARK: - Next prayer

struct NextPrayerIntent: AppIntent {
    static var title: LocalizedStringResource = "الصلاة القادمة"
    static var description = IntentDescription("يعرض وقت الصلاة القادمة.")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let city = DikhrShared.city
        let method = DikhrMethodLoader.method(id: DikhrShared.methodID)
        let times = PrayerTimesEngine.calculate(method: method, lat: city.lat, lng: city.lng, date: Date(), timeZone: .current)
        let upcoming: [(String, Date)] = [
            ("الفجر", times.fajr), ("الشروق", times.sunrise), ("الظهر", times.dhuhr),
            ("العصر", times.asr), ("المغرب", times.maghrib), ("العشاء", times.isha)]
        if let next = upcoming.first(where: { $0.1 > Date() }) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return .result(dialog: IntentDialog(
                full: LocalizedStringResource(stringLiteral: "باقي على أذان \(next.0) \(f.string(from: next.1))"),
                supporting: LocalizedStringResource(stringLiteral: "dikhr")))
        }
        return .result(dialog: "انتهت صلوات اليوم")
    }
}

// MARK: - Shortcuts

struct DikhrShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RandomAthkarIntent(),
            phrases: ["\u{0623}\u{0630}\u{0643}\u{0627}\u{0631} \u{0645}\u{0646}\u{0648}\u{0639}\u{0629} \u{0641}\u{064A} \(.applicationName)"],
            shortTitle: "أذكار منوعة",
            systemImageName: "sparkles")
        AppShortcut(
            intent: IncrementCounterIntent(),
            phrases: ["\u{0632}\u{0627}\u{062F} \u{0627}\u{0644}\u{0639}\u{062F}\u{0627}\u{062F} \u{0641}\u{064A} \(.applicationName)"],
            shortTitle: "العداد",
            systemImageName: "stopwatch")
        AppShortcut(
            intent: NextPrayerIntent(),
            phrases: ["\u{0627}\u{0644}\u{0635}\u{0644}\u{0627}\u{0629} \u{0627}\u{0644}\u{0642}\u{0627}\u{062F}\u{0645}\u{0629} \u{0641}\u{064A} \(.applicationName)"],
            shortTitle: "الصلاة القادمة",
            systemImageName: "clock")
    }
}
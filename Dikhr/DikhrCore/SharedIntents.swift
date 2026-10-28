import Foundation
import AppIntents
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Loads the bundled prayer-calculation methods (bundled in DikhrCore/Resources),
/// shared by the app and the widget extension.
enum DikhrMethodLoader {
    static func loadAll() -> [PrayerMethod] {
        guard let url = Bundle.main.url(forResource: "prayer_methods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = raw["prayerCalculation"] as? [[String: Any]],
              let listData = try? JSONSerialization.data(withJSONObject: list),
              let methods = try? JSONDecoder().decode([PrayerMethod].self, from: listData)
        else { return [] }
        return methods
    }

    static func method(id: String) -> PrayerMethod {
        loadAll().first(where: { $0.params == id }) ?? fallback
    }

    static var fallback: PrayerMethod {
        PrayerMethod(fajrAngle: 18.5, ishaAngle: 0, ishaInterval: 90,
                     name: "تقويم أم القرى", params: "ummAlQura")
    }
}

/// Shared between the app and the interactive counter widget.
struct IncrementCounterIntent: AppIntent {
    static var title: LocalizedStringResource = "زيادة العداد"
    static var description = IntentDescription("يزيد العداد الحالي بواحد ويعرض النتيجة.")

    @Parameter(title: "العداد")
    var counterName: String?

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var counters = DikhrShared.loadCounters()
        let target: SavedCounter
        if let counterName, let found = counters.first(where: { $0.name == counterName }) {
            target = found
        } else if let first = counters.first {
            target = first
        } else {
            return .result(dialog: "لا يوجد عداد")
        }
        let newValue = target.count + 1
        if let idx = counters.firstIndex(where: { $0.id == target.id }) {
            counters[idx].count = newValue
            DikhrShared.saveCounters(counters)
            #if canImport(ActivityKit) && os(iOS)
            DikhrLiveActivity.update(count: newValue, name: target.name)
            #endif
            // Keep the interactive counter tile honest between snapshots.
            // Keep the interactive counter tile honest between snapshots.
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "DikhrCounter")
            WidgetCenter.shared.reloadTimelines(ofKind: "DikhrDailyTasks")
            #endif
        }
        return .result(dialog: "\(target.name): \(newValue)")
    }
}
import Foundation

/// Cross-process storage (app + widget extension) through the app group.
enum DikhrShared {
    static let appGroupID = "group.dev.dikhr.app.shared"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Counters

    static func loadCounters() -> [SavedCounter] {
        guard let data = defaults.data(forKey: "counters"),
              let list = try? JSONDecoder().decode([SavedCounter].self, from: data)
        else {
            return [SavedCounter(name: "سبحان الله", count: 0, target: 33),
                    SavedCounter(name: "الحمد لله", count: 0, target: 33),
                    SavedCounter(name: "لا إله إلا الله", count: 0, target: 33),
                    SavedCounter(name: "الله أكبر", count: 0, target: 34)]
        }
        return list
    }

    static func saveCounters(_ counters: [SavedCounter]) {
        if let data = try? JSONEncoder().encode(counters) {
            defaults.set(data, forKey: "counters")
        }
    }

    // MARK: - Prayer prefs

    static var city: City {
        get { loadCity() ?? City(name: "مكة المكرمة", lat: 21.4225, lng: 39.8262, country: "sa") }
        set { saveCity(newValue) }
    }

    static var methodID: String {
        get { defaults.string(forKey: "prayerMethod") ?? "ummAlQura" }
        set { defaults.set(newValue, forKey: "prayerMethod") }
    }

    static func loadCity() -> City? {
        guard let dict = defaults.dictionary(forKey: "savedCity") else { return nil }
        return City(name: dict["name"] as? String ?? "",
                    lat: dict["lat"] as? Double ?? 0,
                    lng: dict["lng"] as? Double ?? 0,
                    tag: dict["tag"] as? String,
                    country: (dict["country"] as? String) ?? "")
    }

    static func saveCity(_ city: City) {
        defaults.set(["name": city.name, "lat": city.lat, "lng": city.lng,
                      "tag": city.tag ?? "", "country": city.country],
                     forKey: "savedCity")
    }
}

enum CounterStore {
    static func load() -> [SavedCounter] { DikhrShared.loadCounters() }
    static func save(_ counters: [SavedCounter]) { DikhrShared.saveCounters(counters) }
}
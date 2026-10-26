import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    static var shared = SettingsStore()

    enum Language: String, CaseIterable {
        case arabic
        case english
    }

    @Published var lang: Language {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") }
    }
    @Published var city: City {
        didSet {
            persistCity()
            DikhrShared.saveCity(city)
        }
    }
    @Published var methodID: String {
        didSet {
            UserDefaults.standard.set(methodID, forKey: "prayerMethod")
            DikhrShared.methodID = methodID
        }
    }
    @Published var fontSizeBoost: Bool {
        didSet { UserDefaults.standard.set(fontSizeBoost, forKey: "fontSizeBoost") }
    }
    @Published var hijriAdjustment: Int {
        didSet { UserDefaults.standard.set(hijriAdjustment, forKey: "hijriAdjustment") }
    }
    @Published var showTranslation: Bool {
        didSet { UserDefaults.standard.set(showTranslation, forKey: "showTranslation") }
    }
    @Published var accentIndex: Int {
        didSet { UserDefaults.standard.set(accentIndex, forKey: "accentIndex") }
    }
    @Published var useAutoLocation: Bool {
        didSet {
            UserDefaults.standard.set(useAutoLocation, forKey: "useAutoLocation")
            mirrorCurrentCity()
        }
    }
    @Published var detectedCity: City? {
        didSet { mirrorCurrentCity() }
    }
    @Published var appearanceMode: String {
        didSet { UserDefaults.standard.set(appearanceMode, forKey: "appearanceMode") }
    }
    @Published var favorites: Set<String> {
        didSet {
            if let data = try? JSONEncoder().encode(favorites) {
                UserDefaults.standard.set(data, forKey: "favorites")
            }
        }
    }

    private init() {
        let d = UserDefaults.standard
        lang = Language(rawValue: d.string(forKey: "lang") ?? "") ?? .arabic
        city = SettingsStore.loadSavedCity() ?? DikhrShared.loadCity() ?? City(name: "مكة المكرمة", lat: 21.4225, lng: 39.8262, country: "sa")
        methodID = d.string(forKey: "prayerMethod") ?? DikhrShared.methodID
        fontSizeBoost = d.bool(forKey: "fontSizeBoost")
        hijriAdjustment = d.integer(forKey: "hijriAdjustment")
        showTranslation = d.bool(forKey: "showTranslation")
        accentIndex = d.object(forKey: "accentIndex") as? Int ?? 0
        appearanceMode = d.string(forKey: "appearanceMode") ?? "system"
        useAutoLocation = d.object(forKey: "useAutoLocation") as? Bool ?? true
        if let data = d.data(forKey: "favorites"),
           let set = try? JSONDecoder().decode(Set<String>.self, from: data) {
            favorites = set
        } else {
            favorites = []
        }
    }

    static func loadSavedCity() -> City? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "savedCity") else { return nil }
        return City(name: dict["name"] as? String ?? "",
                    lat: dict["lat"] as? Double ?? 0,
                    lng: dict["lng"] as? Double ?? 0,
                    tag: dict["tag"] as? String,
                    country: (dict["country"] as? String) ?? "")
    }

    /// The city prayer times actually run on: device location when auto mode
    /// and a fix is available, otherwise the manually chosen city.
    var currentCity: City {
        if useAutoLocation,
           let c = detectedCity,
           abs(c.lat) > 0.001, abs(c.lng) > 0.001 {
            return c
        }
        return city
    }

    var isUsingDeviceLocation: Bool { useAutoLocation && currentCity != city }

    private func mirrorCurrentCity() {
        DikhrShared.saveCity(currentCity)
    }

    private func persistCity() {
        UserDefaults.standard.set(["name": city.name, "lat": city.lat, "lng": city.lng,
                                   "tag": city.tag ?? "", "country": city.country],
                                  forKey: "savedCity")
    }

    static func loadCities() -> [(code: String, name: String, cities: [City])] {
        guard let url = Bundle.main.url(forResource: "MainCities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let countries = raw["CitiesList"] as? [String: [[String: Any]]]
        else { return [] }
        let countryNames: [String: String] = ["sa": "السعودية", "ae": "الإمارات", "eg": "مصر", "kw": "الكويت",
                                              "qa": "قطر", "bh": "البحرين", "om": "عمان", "jo": "الأردن",
                                              "ps": "فلسطين", "iq": "العراق", "sy": "سوريا", "lb": "لبنان",
                                              "ye": "اليمن", "ma": "المغرب", "dz": "الجزائر", "tn": "تونس",
                                              "ly": "ليبيا", "sd": "السودان", "tr": "تركيا", "de": "ألمانيا",
                                              "fr": "فرنسا", "gb": "بريطانيا", "us": "أمريكا", "ca": "كندا",
                                              "au": "أستراليا", "id": "إندونيسيا", "my": "ماليزيا", "pk": "باكستان",
                                              "bd": "بنغلاديش", "in": "الهند", "nl": "هولندا", "es": "إسبانيا",
                                              "sv": "السويد", "no": "النرويج", "dk": "الدنمارك", "br": "برازيل"]
        let order: [String] = ["sa", "ae", "eg", "kw", "qa", "bh", "om", "jo", "ps", "iq", "sy", "lb", "ye",
                               "ma", "dz", "tn", "ly", "sd", "tr", "de", "fr", "gb", "us", "ca", "au",
                               "id", "my", "pk", "bd", "in", "nl", "es", "sv", "no", "dk", "br"]
        var result: [(String, String, [City])] = []
        for code in order where countries[code] != nil {
            let cities = (countries[code] ?? []).compactMap { dict -> City? in
                guard let name = dict["name"] as? String,
                      let lat = dict["lat"] as? Double,
                      let lng = dict["lng"] as? Double
                else { return nil }
                return City(name: name, lat: lat, lng: lng,
                            tag: dict["tag"] as? String, country: code)
            }
            result.append((code, countryNames[code] ?? code, cities))
        }
        return result
    }

    static func loadMethods() -> [PrayerMethod] {
        DikhrMethodLoader.loadAll()
    }

    var bodyFontScale: CGFloat { fontSizeBoost ? 1.4 : 1.0 }

    /// Nearest bundled city to a coordinate (haversine, degrees km).
    static func nearestCity(latitude: Double, longitude: Double) -> City? {
        var best: (city: City, distance: Double)?
        for section in loadCities() {
            for city in section.2 {
                let d = haversineKm(lat1: latitude, lng1: longitude,
                                    lat2: city.lat, lng2: city.lng)
                if best == nil || d < best!.distance {
                    best = (city, d)
                }
            }
        }
        return best?.city
    }

    static func haversineKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let r = 6371.0
        func rad(_ d: Double) -> Double { d * .pi / 180 }
        let dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1)
        let a = sin(dLat/2) * sin(dLat/2) +
            cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng/2) * sin(dLng/2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    var accentColor: Color { ThemePalette.colors.indices.contains(accentIndex) ? ThemePalette.colors[accentIndex] : ThemePalette.colors[0] }
    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

enum ThemePalette {
    static let names = ["فيروزي", "أخضر", "أزرق", "بنفسجي", "برتقالي", "ذهبي"]
    static let colors: [Color] = [
        Color(red: 0.00, green: 0.56, blue: 0.62),
        Color(red: 0.10, green: 0.62, blue: 0.35),
        Color(red: 0.20, green: 0.44, blue: 0.86),
        Color(red: 0.52, green: 0.32, blue: 0.84),
        Color(red: 0.93, green: 0.44, blue: 0.18),
        Color(red: 0.82, green: 0.62, blue: 0.14),
    ]
}
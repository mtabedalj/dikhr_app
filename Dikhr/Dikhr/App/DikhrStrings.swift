import Foundation
import SwiftUI

/// Lightweight Arabic/English string switcher.
///
/// Arabic stays the primary/fallback string. English is a hand-written
/// concise UI translation returned when `settings.lang == .english`.
///
/// Live updates: views that hold `@EnvironmentObject var settings: SettingsStore`
/// re-evaluate their body when `lang` changes, so `settings.t(...)` switches
/// instantly. Views without settings access use `DikhrStrings.tr(...)` with the
/// UserDefaults-mirrored `DikhrStrings.lang` (still correct at each fresh
/// render, but it does not by itself trigger a re-render).
enum DikhrStrings {
    /// Mirrors SettingsStore.lang, persisted under the "lang" UserDefaults key.
    static var lang: SettingsStore.Language {
        SettingsStore.Language(rawValue: UserDefaults.standard.string(forKey: "lang") ?? "") ?? .arabic
    }

    /// Returns `ar` in Arabic mode, `en` in English mode.
    static func tr(_ ar: String, _ en: String) -> String {
        lang == .arabic ? ar : en
    }
}

extension SettingsStore {
    /// Per-language string accessor for views observing this store.
    /// Usage: `Text(settings.t("العربية", "Arabic"))` — re-evaluates live on language switch.
    func t(_ ar: String, _ en: String) -> String {
        lang == .arabic ? ar : en
    }

    /// City name honoring the language: English parses the bundled `tag`
    /// column (its latin search tokens) into a capitalized name.
    func cityName(_ city: City) -> String {
        guard lang == .english else { return city.name }
        let latin = (city.tag ?? "")
            .split(separator: " ")
            .first { $0.allSatisfy { $0.isASCII } && $0.contains(where: { $0.isLetter }) }
        guard let latin else { return city.name }
        return latin.prefix(1).uppercased() + latin.dropFirst().lowercased()
    }
}

/// English display names for prayer kinds (arabicName lives in DikhrCore and
/// must stay untouched, so the English side is mirrored here).
extension PrayerKind {
    var englishName: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }

    /// Localized name resolved per Arabic/English mode.
    func name(_ lang: SettingsStore.Language) -> String {
        lang == .arabic ? arabicName : englishName
    }
}
import CryptoKit
import Foundation

/// Plain-text athkar section pushed to the watch (WatchKit original shows
/// enabled sections as plain text only).
struct AthkarSectionPlain: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var text: String
}

/// Message keys shared between the iPhone sender (WatchPhoneBridge) and the
/// watch receiver (WatchSessionReceiver).
enum WatchSyncKeys {
    /// Full applicationContext payload: Data-encoded JSON for each key.
    static let athkarSections = "athkarSections"
    static let counters = "counters"
    static let city = "city"
    static let method = "method"
    static let pushedHash = "athkarPushedHash"

    /// Live message from the watch after a counter tap.
    static let counterUpdate = "counterUpdate"

    /// Watch-only key: asks the phone for a fresh full push.
    static let requestRefresh = "requestRefresh"
}

/// Conversion + fingerprint helpers for the phone → watch athkar push
/// (mirrors the original's `watchMyAthkarPushedHash` guard).
enum WatchAthkarSync {
    /// Sections whose ids are enabled for the watch, ordered per AthkarStore.
    static func sections(from categories: [(id: String, title: String, entries: [AthkarEntry])],
                         enabled: Set<String>) -> [AthkarSectionPlain] {
        categories
            .filter { enabled.contains($0.id) }
            .map { category in
                let body = category.entries
                    .compactMap { entry -> String? in
                        var parts: [String] = []
                        if let title = entry.Title, !title.isEmpty { parts.append(title) }
                        if let athkar = entry.Athkar { parts.append(plainText(from: athkar)) }
                        let joined = parts.joined(separator: "\n")
                        return joined.isEmpty ? nil : joined
                    }
                    .joined(separator: "\n\n")
                return AthkarSectionPlain(id: category.id, title: category.title, text: body)
            }
    }

    /// WatchOS-safe HTML stripping (no NSAttributedString HTML parsing there).
    static func plainText(from html: String) -> String {
        var t = html
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "<p>", with: "\n")
            .replacingOccurrences(of: "</p>", with: "\n")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>") {
            let range = NSRange(t.startIndex..., in: t)
            t = regex.stringByReplacingMatches(in: t, range: range, withTemplate: "")
        }
        while t.contains("\n\n\n") { t = t.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Stable fingerprint of section content, used to skip redundant pushes.
    static func fingerprint(_ sections: [AthkarSectionPlain]) -> String {
        let encoded = (try? JSONEncoder().encode(sections)) ?? Data()
        return SHA256.hash(data: encoded).compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension DikhrShared {
    /// Sections currently pushed to / cached for the watch (app group when
    /// entitled; local fallback otherwise).
    static var watchAthkarSections: [AthkarSectionPlain] {
        guard let data = defaults.data(forKey: "watchAthkarSections"),
              let list = try? JSONDecoder().decode([AthkarSectionPlain].self, from: data)
        else { return [] }
        return list
    }

    static func saveWatchAthkarSections(_ sections: [AthkarSectionPlain]) {
        if let data = try? JSONEncoder().encode(sections) {
            defaults.set(data, forKey: "watchAthkarSections")
        }
    }

    /// Category ids enabled with the phone's "استخدم في الساعة" toggle.
    /// Defaults on the daily sections before the user ever opens the toggle list.
    static var watchSectionIDs: Set<String> {
        let saved = defaults.stringArray(forKey: "watchSectionIDs")
        return Set(saved ?? ["Page1", "Page2", "Page5", "Page3"])
    }

    static func saveWatchSectionIDs(_ ids: Set<String>) {
        // Persisting empty stores a marker so explicit "all off" sticks.
        defaults.set(Array(ids).sorted(), forKey: "watchSectionIDs")
    }

    static var watchPushedHash: String {
        defaults.string(forKey: "watchAthkarPushedHash") ?? ""
    }

    static func setWatchPushedHash(_ hash: String) {
        defaults.set(hash, forKey: "watchAthkarPushedHash")
    }
}
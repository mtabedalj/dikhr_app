import Foundation

struct AthkarCategory: Identifiable, Hashable {
    var id: String
    var title: String
    var entries: [AthkarEntry]
}

enum AthkarStore {
    static let categoryTitles: [String: String] = [
        "Page1": "أذكار الصباح",
        "Page2": "أذكار المساء",
        "Page3": "أذكار النوم",
        "Page31": "أذكار الاستيقاظ",
        "Page4": "الأدعية المأثورة",
        "Page5": "أذكار بعد الصلاة",
        "Page6": "أدعية متفرقة",
        "Page7": "أدعية من القرآن",
        "Page8": "أدعية النبي صلى الله عليه وسلم",
        "AkherAyateen": "آيات خاتمة",
        "RoqiaQuran": "الرقية بالقرآن",
        "RoqiaSuna": "الرقية بالسنة",
        "Tasbee7": "التسبيح"
    ]

    static func loadCategories() -> [AthkarCategory] {
        guard let url = Bundle.main.url(forResource: "athkar_pages", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        var categories: [AthkarCategory] = []
        for (key, value) in raw {
            guard let entriesData = try? JSONSerialization.data(withJSONObject: value),
                  let entries = try? JSONDecoder().decode([AthkarEntry].self, from: entriesData)
            else { continue }
            categories.append(AthkarCategory(id: key, title: categoryTitles[key] ?? key, entries: entries))
        }
        categories.sort { categoryOrderIndex($0.id) < categoryOrderIndex($1.id) }
        return categories
    }

    static func loadMix() -> [String] {
        guard let url = Bundle.main.url(forResource: "mix", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mix = raw["Mix"] as? [String]
        else { return [] }
        return mix
    }

    static func loadNinetyNineNames() -> [(name: String, details: String)] {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let names = raw["allahNames"] as? [[String: Any]]
        else { return [] }
        return names.compactMap { e in
            guard let n = e["Name"] as? String else { return nil }
            return (n, e["Details"] as? String ?? "")
        }
    }

    private static let orderMap: [String: Int] = Dictionary(uniqueKeysWithValues:
        ["Page1","Page2","Page3","Page31","Page5","Page7","Page8","Page6","Page4","AkherAyateen","Tasbee7","RoqiaQuran","RoqiaSuna"]
            .enumerated().map { idx, key in (key, idx) })

    private static func categoryOrderIndex(_ key: String) -> Int {
        orderMap[key] ?? 100
    }

    private static var htmlCache: [String: String] = [:]

    /// Parses athkar HTML (the bundled texts contain malformed markup from the
    /// original editor) through NSAttributedString, which tolerates bad HTML.
    static func htmlToPlain(_ html: String) -> String {
        if let cached = htmlCache[html] { return cached }
        var plain = html
        if let attr = try? NSAttributedString(
            data: Data(html.utf8),
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil) {
            plain = attr.string
        }
        plain = plain
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while plain.contains("  ") { plain = plain.replacingOccurrences(of: "  ", with: " ") }
        htmlCache[html] = plain
        return plain
    }

    static func stripHTML(_ html: String) -> String {
        var t = html
        t = t.replacingOccurrences(of: "<br>", with: "\n")
        t = t.replacingOccurrences(of: "<br/>", with: "\n")
        t = t.replacingOccurrences(of: "<br />", with: "\n")
        t = t.replacingOccurrences(of: "\n", with: " ")
        t = t.replacingOccurrences(of: "&nbsp;", with: " ")
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>"),
              let data = t.data(using: .utf8)
        else { return t }
        var text = regex.stringByReplacingMatches(in: t, options: [], range: NSRange(location: 0, length: data.count / 4), withTemplate: " ")
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
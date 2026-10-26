import SwiftUI

/// Splits athkar HTML into styled segments matching the original Athkar
/// typography (`light.css`/`dark.css`). Classes actually present in the athkar
/// data (`athkarList.plist` → Dikhr’s `athkar_pages.json`):
/// - `<div class='quran'>` — mushaf verse blocks → Uthmani font, adaptive green.
/// - `<p class="left">` — repetition-count line → ExpoArabic-Book, small,
///   centered in the original; rendered as a caption segment.
/// - `<span>`, `<span class="noHide">`, `<span class="Left">` — the original’s
///   `#main span` rule tinted these inline notes/attributions with the page
///   accent (#003976 light / #0aa3c8 dark) → note segments.
/// - `<h3>` — bismillah/basemala headings → bold accent heading.
/// Everything else is body text. `mashy` / `trans` classes do not appear in the
/// athkar data, so they are not modeled.
enum AthkarTextRenderer {
    enum SegmentStyle: Equatable {
        case quran
        case body
        case note
        case attribution
        case heading
    }

    struct Segment: Identifiable {
        var id: Int
        var text: String
        var style: SegmentStyle

        /// Compatibility shim: the card view predates styling and only knows
        /// `isQuran`.
        var isQuran: Bool { style == .quran }
    }

    private static let patterns: [(SegmentStyle, NSRegularExpression)] = { [
        (SegmentStyle.quran, try! NSRegularExpression(
            pattern: "<div\\s+class=['\"]quran['\"]>([\\s\\S]*?)</div>")),
        (SegmentStyle.heading, try! NSRegularExpression(
            pattern: "<h[1-6][^>]*>([\\s\\S]*?)</h[1-6]>")),
        (SegmentStyle.attribution, try! NSRegularExpression(
            pattern: "<p\\s+class=['\"](?:left|Left)['\"][^>]*>([\\s\\S]*?)</p>")),
        (SegmentStyle.note, try! NSRegularExpression(
            pattern: "<span[^>]*>([\\s\\S]*?)</span>")),
    ] }()

    static func segments(_ html: String) -> [Segment] {
        guard !html.isEmpty else { return [] }
        let ns = html as NSString
        let full = NSRange(location: 0, length: ns.length)
        // Collect every block-level match, then process them in source order,
        // skipping anything nested inside an earlier match (e.g. a <span>
        // inside a .quran block renders in the verse style).
        var matches: [(style: SegmentStyle, inner: NSRange, outer: NSRange)] = []
        for (style, regex) in patterns {
            for m in regex.matches(in: html, options: [], range: full) {
                let inner = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range
                matches.append((style, inner, m.range))
            }
        }
        matches.sort { $0.outer.location < $1.outer.location }

        var out: [Segment] = []
        var cursor = 0
        for match in matches {
            guard match.outer.location >= cursor else { continue }
            if match.outer.location > cursor {
                let plain = strip(ns.substring(with: NSRange(location: cursor, length: match.outer.location - cursor)))
                if !plain.isEmpty { out.append(Segment(id: out.count, text: plain, style: .body)) }
            }
            let text = strip(ns.substring(with: match.inner)).trimmingCharacters(in: .whitespacesAndNewlines)
            let style = match.style
            if !text.isEmpty { out.append(Segment(id: out.count, text: text, style: style)) }
            cursor = NSMaxRange(match.outer)
        }
        if cursor < ns.length {
            let plain = strip(ns.substring(with: NSRange(location: cursor, length: ns.length - cursor)))
            if !plain.isEmpty { out.append(Segment(id: out.count, text: plain, style: .body)) }
        }
        // Drop leading empty body blocks left by <br/> fences and re-label.
        let compact = out.filter { !$0.text.isEmpty }
        return compact.enumerated().map { Segment(id: $0.offset, text: $0.element.text, style: $0.element.style) }
    }

    // MARK: Styling (per light.css / dark.css)

    private static let accent = Color(
        light: Color(red: 0 / 255, green: 57 / 255, blue: 118 / 255),   // #003976
        dark: Color(red: 10 / 255, green: 163 / 255, blue: 200 / 255)) // #0aa3c8

    static func font(_ style: SegmentStyle) -> Font {
        switch style {
        case .quran:
            return .quranUthmani // UthmanicHafs 26 — the original's 150% mushaf sizing
        case .body, .note:
            return .athkarBody // Scheherazade 21 — body copy scale
        case .attribution:
            return .custom("ExpoArabic-Book", size: 14) // CSS 11px at body scale
        case .heading:
            return .custom("ExpoArabic-Book", size: 16).weight(.semibold) // CSS h3: bold 12pt
        }
    }

    static func foregroundColor(_ style: SegmentStyle) -> Color {
        switch style {
        case .quran:
            return QuranPalette.darkGreen // mushaf green per Dikhr convention
        case .note, .heading:
            return accent // the original's #main span / h3 accent
        case .body, .attribution:
            return .primary
        }
    }

    static func lineSpacing(_ style: SegmentStyle) -> CGFloat {
        switch style {
        case .quran: return 16 // CSS line-height 1.75
        case .body: return 10  // CSS #main line-height 25px
        case .note, .attribution, .heading: return 8
        }
    }

    static func alignment(_ style: SegmentStyle) -> TextAlignment? {
        switch style {
        case .attribution: return .center // CSS p.left: text-align center
        case .quran, .body, .note, .heading: return .leading
        }
    }

    private static func strip(_ html: String) -> String {
        var t = html
        t = t.replacingOccurrences(of: "<br>", with: "\n")
        t = t.replacingOccurrences(of: "<br/>", with: "\n")
        t = t.replacingOccurrences(of: "<br />", with: "\n")
        t = t.replacingOccurrences(of: "<hr>", with: "\n\n")
        t = t.replacingOccurrences(of: "<hr/>", with: "\n\n")
        t = t.replacingOccurrences(of: "<hr />", with: "\n\n")
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>") else { return t }
        t = regex.stringByReplacingMatches(in: t, options: [], range: NSRange(location: 0, length: (t as NSString).length), withTemplate: " ")
        t = t.replacingOccurrences(of: "&nbsp;", with: " ")
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        // Collapse whitespace around line breaks; single breaks only
        t = t.replacingOccurrences(of: "\n ", with: "\n")
        t = t.replacingOccurrences(of: " \n", with: "\n")
        while t.contains("\n\n") { t = t.replacingOccurrences(of: "\n\n", with: "\n") }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return t
    }
}
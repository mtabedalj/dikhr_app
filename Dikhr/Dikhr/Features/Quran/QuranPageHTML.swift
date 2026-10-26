import SwiftUI
import WebKit

/// Printed-mushaf page rendering (المصحف المطبوع). Page-scoped variant of the
/// MushafHTMLView technique (same @font-face + paper CSS pattern, reused without
/// editing it): every printed page (1–604) renders its ayat as ONE continuous
/// justified Uthmanic block, with surah-opening medallions / bismillah lines
/// inserted inline wherever a surah starts on the page.
enum QuranPageHTML {
    static func arabicDigits(_ n: Int) -> String {
        MushafHTMLView.arabicDigits(n)
    }

    /// `juzLabel` / `bandSurahName` come from the pages table via QuranPageStore.
    static func pageHTML(page: Int, ayahs: [QuranAyah],
                         juzLabel: String? = nil,
                         bandSurahName: String? = nil,
                         bookmarkedAyahs: Set<String> = []) -> String {
        var flow = ""
        var previousSurahID: Int?
        for (index, run) in runs(ayahs).enumerated() {
            if let s = QuranDatabase.shared.surah(run.surahID) {
                // A surah opens on this page when its ayah 1 appears here, or
                // when a mid-page ayah belongs to a new surah.
                let opensHere = index == 0
                    ? run.ayahs.first?.number == 1
                    : run.surahID != previousSurahID
                if opensHere, let name = QuranDatabase.shared.surah(run.surahID)?.name {
                    flow += "<div class='shead'><div class='rosette'>❁</div><div class='sname'>\(name)</div></div>"
                    if ![1, 9].contains(run.surahID) {
                        flow += "<div class='bismillah'>بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ</div>"
                    }
                }
            }
            flow += run.ayahs.map { ayah -> String in
                let marker = "<span class='m'>" + arabicDigits(ayah.number) + "</span>"
                // Bookmarked verse: `<mark>`-styled yellow highlight
                // (the original's `.highlight{background-color:yellow}`).
                if bookmarkedAyahs.contains("\(run.surahID):\(ayah.number)") {
                    return "<span class='bkm'>" + ayah.text + "</span> " + marker + " "
                }
                return ayah.text + " " + marker + " "
            }.joined()
            previousSurahID = run.surahID
        }

        let band = (bandSurahName?.isEmpty == false) ? bandSurahName! : ""
        let juzText = juzLabel ?? ""
        return """
        <!DOCTYPE html><html dir="rtl" lang="ar"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
        @font-face { font-family: 'UtB'; src: url('UthmanicHafs_V22_Bold.ttf'); }
        @font-face { font-family: 'Sch'; src: url('Scheherazade-Regular.ttf'); }
        :root{
          --green:#00946a; --paper:#F7F5EF; --ink:#26241F;
          --faded:#8A8578; --hairline:rgba(60,55,40,.28);
        }
        @media (prefers-color-scheme: dark){
          :root{ --paper:#1C1B18; --ink:#EDE9E0; --faded:#9B958A; --hairline:rgba(237,233,224,.28); }
        }
        *{ margin:0; padding:0; box-sizing:border-box; }
        html,body{ background:var(--paper); color:var(--ink);
          font-family:'Sch',serif; -webkit-text-size-adjust:100%; }
        .page{ padding:14px 16px 26px; }
        .band{ display:flex; align-items:center; justify-content:space-between;
          color:var(--faded); font-size:13px;
          font-family:-apple-system,'SF Arabic',sans-serif; }
        .band .juz{ color:var(--green); font-weight:600; }
        .band .juz .r{ color:var(--green); }
        .bandname{ text-align:center; color:var(--green); font-weight:700;
          font-family:-apple-system,'SF Arabic',sans-serif; font-size:15px;
          margin-top:2px; padding-bottom:10px; border-bottom:1px solid var(--hairline); }
        .mushaf{ font-family:'UtB'; font-size:23px; line-height:2.2;
          text-align:justify; text-align-last:center; direction:rtl; }
        .mushaf .m{ color:var(--green); }
        .mushaf .bkm{ background-color:yellow; }
        .shead{ text-align:center; margin:10px 0 8px; }
        .shead .rosette{ color:var(--green); font-size:20px; line-height:1.2; }
        .shead .sname{ color:var(--green); font-weight:700; font-size:23px;
          font-family:-apple-system,'SF Arabic',sans-serif; margin-top:4px; }
        .bismillah{ font-family:'UtB'; font-size:21px; color:var(--green);
          text-align:center; margin:2px 0 12px; }
        .foot{ margin-top:16px; display:flex; align-items:center; justify-content:center; gap:10px;
          color:var(--green); font-family:-apple-system,'SF Arabic',sans-serif;
          font-size:13px; font-weight:600; }
        .foot::before,.foot::after{ content:""; display:block; width:44px; height:1px;
          background:var(--hairline); }
        </style></head><body>
        <div class="page">
          <div class="band"><div class="juz"><span class="r">❁</span> \(juzText)</div><div>\(band)</div></div>
          <div class="bandname">صفحة \(arabicDigits(page))</div>
          <div class="mushaf">\(flow)</div>
          <div class="foot">\(arabicDigits(page))</div>
        </div>
        </body></html>
        """
    }

    private struct Run {
        let surahID: Int
        var ayahs: [QuranAyah]
    }

    /// Consecutive ayat belonging to the same surah (a printed page can contain
    /// the tail of one surah, full short surahs, and the head of the next).
    private static func runs(_ ayahs: [QuranAyah]) -> [Run] {
        var out: [Run] = []
        for ayah in ayahs {
            if let last = out.last, last.surahID == ayah.surahID {
                var updated = last
                updated.ayahs.append(ayah)
                out[out.count - 1] = updated
            } else {
                out.append(Run(surahID: ayah.surahID, ayahs: [ayah]))
            }
        }
        return out
    }
}

/// WKWebView wrapper with the same load/dedupe coordinator pattern as
/// MushafHTMLView (fonts load relative to the bundle resource URL).
struct QuranPageWebView: UIViewRepresentable {
    let page: Int
    let ayahs: [QuranAyah]
    let juzLabel: String
    let bandSurahName: String
    /// "surah:ayah" bookmark keys for the yellow `<mark>`-style highlight.
    var bookmarkedAyahs: Set<String> = []

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var currentHTML: String?
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webview = WKWebView(frame: .zero, configuration: configuration)
        webview.isOpaque = false
        webview.backgroundColor = .clear
        webview.scrollView.backgroundColor = .clear
        webview.scrollView.contentInsetAdjustmentBehavior = .never
        let html = QuranPageHTML.pageHTML(page: page, ayahs: ayahs,
                                          juzLabel: juzLabel,
                                          bandSurahName: bandSurahName,
                                          bookmarkedAyahs: bookmarkedAyahs)
        context.coordinator.currentHTML = html
        webview.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
        return webview
    }

    func updateUIView(_ webview: WKWebView, context: Context) {
        let html = QuranPageHTML.pageHTML(page: page, ayahs: ayahs,
                                          juzLabel: juzLabel,
                                          bandSurahName: bandSurahName,
                                          bookmarkedAyahs: bookmarkedAyahs)
        if context.coordinator.currentHTML != html {
            context.coordinator.currentHTML = html
            webview.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
        }
    }
}
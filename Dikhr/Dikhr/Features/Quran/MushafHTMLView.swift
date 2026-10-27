import SwiftUI
import WebKit

/// The mushaf reading page as CSS (like the original app's athkar viewer):
/// paper surface, ornamental header band, justified Uthmanic flow with the
/// font's own circled ayah markers.
struct MushafHTMLView: UIViewRepresentable {
    let surah: QuranSurah
    let ayahs: [QuranAyah]
    /// "surah:ayah" bookmark keys — these verses get the original's
    /// `.highlight{background-color:yellow}` treatment (default: none).
    var bookmarkedAyahs: Set<String> = []
    /// One-shot search jump target shown in THIS surah (or nil): that ayah's
    /// text and circled marker render inside one olive-gold `.jump` block.
    var jumpAyah: QuranJumpTarget.Point? = nil

    static func arabicDigits(_ n: Int) -> String {
        let arabic = ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"]
        return String(n).map { $0.isNumber ? arabic[Int(String($0)) ?? 0] ?? "" : String($0) }.joined()
    }

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
        let html = MushafHTMLView.html(surah: surah, ayahs: ayahs,
                                       bookmarkedAyahs: bookmarkedAyahs,
                                       jumpAyah: jumpAyah)
        context.coordinator.currentHTML = html
        webview.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
        return webview
    }

    func updateUIView(_ webview: WKWebView, context: Context) {
        let html = MushafHTMLView.html(surah: surah, ayahs: ayahs,
                                       bookmarkedAyahs: bookmarkedAyahs,
                                       jumpAyah: jumpAyah)
        if context.coordinator.currentHTML != html {
            context.coordinator.currentHTML = html
            webview.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
        }
    }

    static func html(surah: QuranSurah, ayahs: [QuranAyah],
                     bookmarkedAyahs: Set<String> = [],
                     jumpAyah: QuranJumpTarget.Point? = nil) -> String {
        let flow = ayahs.map { ayah -> String in
            let marker = "<span class='m'>" + arabicDigits(ayah.number) + "</span>"
            // One-shot search jump: text + marker inside one olive-gold block.
            if let jump = jumpAyah, jump.surah == surah.id, jump.ayah == ayah.number {
                return "<span class='jump'>" + ayah.text + " " + marker + "</span> "
            }
            // Bookmarked verse: `<mark>`-styled span == the original's
            // `.highlight{background-color:yellow}` CSS.
            if bookmarkedAyahs.contains("\(surah.id):\(ayah.number)") {
                return "<span class='bkm'>" + ayah.text + "</span> " + marker + " "
            }
            return ayah.text + " " + marker + " "
        }.joined()
        let showBismillah = ![1, 9].contains(surah.id)
        let bismillah = showBismillah ? "<div class='bismillah'>بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ</div>" : ""
        return """
        <!DOCTYPE html><html dir="rtl" lang="ar"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
        @font-face { font-family: 'UtB'; src: url('UthmanicHafs_V22_Bold.ttf'); }
        @font-face { font-family: 'Sch'; src: url('Scheherazade-Regular.ttf'); }
        :root{
          --teal:#018F9E; --green:#00946a; --paper:#F7F5EF; --ink:#26241F;
          --hairline:rgba(60,55,40,.28);
        }
        @media (prefers-color-scheme: dark){
          :root{ --paper:#1C1B18; --ink:#EDE9E0; --hairline:rgba(237,233,224,.28); }
        }
        *{ margin:0; padding:0; box-sizing:border-box; }
        html,body{ background:var(--paper); color:var(--ink);
          font-family:'Sch',serif; -webkit-text-size-adjust:100%; }
        .page{ padding:20px 16px 48px; }
        .bismillah{ font-family:'UtB'; font-size:24px; color:var(--green);
          text-align:center; margin-bottom:14px; }
        .head{ text-align:center; margin-bottom:26px; }
        .rosette{ color:var(--green); font-size:22px; line-height:1.2; }
        .surah-name{ color:var(--green); font-weight:700; font-size:26px; margin:8px 0 10px;
          font-family:-apple-system,'SF Arabic',sans-serif; }
        .meta{ display:flex; align-items:center; justify-content:center; gap:12px;
          color:var(--hairline-ink); color:#8A8578; font-size:13px; }
        .meta::before,.meta::after{ content:""; display:block; width:44px; height:1px;
          background:var(--hairline); }
        .mushaf{ font-family:'UtB'; font-size:26px; line-height:2.35;
          text-align:justify; text-align-last:center; direction:rtl; }
        .mushaf .m{ color:var(--green); }
        .mushaf .bkm{ background-color:yellow; }
        .mushaf .jump{ background-color:rgba(107,97,41,.92); border-radius:7px; padding:2px 10px; }
        </style></head><body>
        <div class="page">
          \(bismillah)
          <div class="head">
            <div class="rosette">❁</div>
            <div class="surah-name">\(surah.name)</div>
            <div class="meta">\(surah.revelationType) • \(surah.ayahCount) آية</div>
          </div>
          <div class="mushaf">\(flow)</div>
        </div>
        </body></html>
        """
    }
}
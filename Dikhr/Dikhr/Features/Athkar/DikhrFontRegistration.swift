import CoreText
import Foundation

/// Registers the fonts Dikhr bakes from the original Athkar bundle into
/// `Resources/Fonts/`. Kept separate from `FontRegistration` in App/ (which is
/// owned by the main session) so this file is self-contained: the app entry
/// only needs to call `DikhrFontRegistration.register()` once at startup.
///
/// Baked fonts (postScript names, verified against the source TTFs):
///  - ExpoArabic-Book.ttf  → "ExpoArabic-Book"  (Athkar CSS `.left` /
///    `a.button` font, also its heading fallback)
/// UthmanicHafs_V22_Bold.ttf ("KFGQPCHAFSUthmanicScript-Bold") and
/// Scheherazade-Regular.ttf ("Scheherazade-Regular") are already registered in
/// App/DikhrApp.swift’s `FontRegistration.registerBundledFonts()`.
enum DikhrFontRegistration {
    private static var registered = false

    static func register() {
        guard !registered else { return }
        registered = true
        let fonts: [(resource: String, subdirectory: String?)] = [
            // Prefer the Fonts/ subfolder; fall back to a flat bundle copy.
            ("ExpoArabic-Book.ttf", "Fonts"),
        ]
        for font in fonts {
            let base = (font.resource as NSString).deletingPathExtension
            guard let url = Bundle.main.url(
                forResource: base,
                withExtension: "ttf",
                subdirectory: font.subdirectory)
                ?? Bundle.main.url(forResource: base, withExtension: "ttf")
            else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
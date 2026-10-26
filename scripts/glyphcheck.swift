import Foundation
import CoreText

let files = ["UtBold-V22": "/Applications/Athkar.app/Wrapper/athkar.app/UthmanicHafs_V22_Bold.ttf",
             "Ver09": "/Applications/Athkar.app/Wrapper/athkar.app/UthmanicHafs1 Ver09.otf"]
let testChars: [UInt32] = [0x6D7, 0x6D8, 0x6D9, 0x6DA, 0x6DB, 0x6DC, 0x6DD, 0x6DE, 0x6DF, 0x6E0, 0x6E1, 0x6E7, 0x6E8, 0x670, 0x671, 0x652, 0x651]

for (label, path) in files {
    guard let scalar0 = Unicode.Scalar(testChars[0]) else { continue }
    let url = URL(fileURLWithPath: path) as CFURL
    let fontDescriptor = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor]
    guard let desc = fontDescriptor?.first else { continue }
    let font = CTFontCreateWithFontDescriptor(desc, 30, nil)
    var covered: [UInt32] = []
    var missing: [UInt32] = []
    for cp in testChars {
        guard let scalar = Unicode.Scalar(cp) else { continue }
        let str = String(Character(scalar))
        var uni = Array(str.utf16)
        var glyphBuf = [CGGlyph](repeating: CGGlyph(), count: uni.count)
        let ok = CTFontGetGlyphsForCharacters(font, uni, &glyphBuf, uni.count)
        let hasNonZero = ok && glyphBuf.contains(where: { $0 != 0 })
        if hasNonZero { covered.append(cp) } else { missing.append(cp) }
    }
    print(label)
    print("  covered:", covered.map { String(format: "U+%04X", $0) }.joined(separator: " "))
    print("  missing:", missing.map { String(format: "U+%04X", $0) }.joined(separator: " "))
    _ = scalar0
}
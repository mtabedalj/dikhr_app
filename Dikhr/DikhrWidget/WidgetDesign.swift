import SwiftUI
import AppIntents

// MARK: - Widget design system (the original's MyWidget* look, Dikhr side)
//
// Evidence from the original extension (athkarWidgetExtension):
//   · accent from its Assets: 0.462, 0.838, 1.0 = #76D6FF (DeviceWidgetAccent),
//     also used by Dikhr's watch theme (DikhrWatchApp.swift).
//   · MyWidgetTornPaper / MyWidgetWave dark vector backgrounds; dark design on
//     the prayer widget (MyWidgetFivePrayersElement + MyWidgetNextPrayerInk).
//   · AR strings: "الوقت المتبقي" caption, countdown format "%1$@س %2$@د".

enum WidgetInk {
    /// The original widget accent (#76D6FF).
    static let accent = Color(red: 0.462, green: 0.838, blue: 1.0)

    /// Dark canvas stops (solid/dark design).
    static let canvasTop = Color(red: 0.043, green: 0.055, blue: 0.071)
    static let canvasBottom = Color(red: 0.078, green: 0.106, blue: 0.137)
    static let cardFill = Color.white.opacity(0.07)
    static let hairline = Color.white.opacity(0.16)
}

// MARK: - Locale-based digits (the original's: Arabic digits when the locale is Arabic)

enum WidgetLocaleDigits {
    static let isArabic: Bool =
        Locale.current.language.languageCode == .arabic

    private static let arabicZeroToNine: [Character] =
        ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]

    /// Converts ASCII digits only, e.g. "4" → "٤"; leaves Latin text untouched
    /// when the locale is not Arabic.
    static func apply(_ text: String) -> String {
        guard isArabic else { return text }
        return String(text.map { char in
            guard let ascii = char.asciiValue, (48...57).contains(ascii) else { return char }
            return arabicZeroToNine[Int(ascii - 48)]
        })
    }

    /// Short clock time, Arabic-Indic digits in Arabic locales (like the original's
    /// prayer rows), system short format otherwise.
    static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = TimeZone.current
        formatter.locale = isArabic ? Locale(identifier: "ar_001") : .current
        return apply(formatter.string(from: date))
    }
}

// MARK: - Background designer: 3 selectable vector backgrounds
//
// The configurable enum is persisted by WidgetKit itself as the widget's AppIntent
// configuration (long-press → "تعديل" → الخلفية) — no manual storage needed.

enum WidgetBackgroundKind: String, AppEnum, Codable, Hashable {
    case dark
    case tornPaper
    case wave

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "الخلفية")
    }
    static var caseDisplayRepresentations: [WidgetBackgroundKind: DisplayRepresentation] {
        [
        .dark: .init(title: "داكن سادة", image: .init(systemName: "square.fill")),
        .tornPaper: .init(title: "ورقة ممزقة", image: .init(systemName: "square.bottomthird.inset.filled")),
        .wave: .init(title: "موجات", image: .init(systemName: "curlybraces.square.fill")),
        ]
    }
}

extension View {
    /// containerBackground with the selected designer background (shared by all
    /// widget files).
    @ViewBuilder
    func containerBackgroundCompat(_ kind: WidgetBackgroundKind) -> some View {
        containerBackground(for: .widget) {
            widgetBackgroundPainter(kind)
        }
    }
}

/// Painters live OUTSIDE the AppEnum: the AppIntents macro crashes the
/// frontend while const-evaluating enum members containing result builders.
@ViewBuilder
func widgetBackgroundPainter(_ kind: WidgetBackgroundKind) -> some View {
    switch kind {
    case .dark: widgetSolidPaint
    case .tornPaper: widgetTornPaperPaint
    case .wave: widgetWavePaint
    }
}

private var widgetSolidPaint: some View {
    LinearGradient(colors: [WidgetInk.canvasTop, WidgetInk.canvasBottom],
                   startPoint: .top, endPoint: .bottom)
}

/// Torn paper (the original's MyWidgetTornPaper): a torn lower sheet over the
/// dark canvas with speckle grain and an accent tear hairline.
private var widgetTornPaperPaint: some View {
    ZStack {
        widgetSolidPaint
        TornEdgeShape(tearFraction: 0.62)
            .fill(Color(white: 0.14).opacity(0.85))
        TornEdgeShape(tearFraction: 0.63)
            .stroke(WidgetInk.accent.opacity(0.35), lineWidth: 1)
        SpeckleGrain()
    }
}

/// Faint deterministic speckles (MyWidgetSpeckles).
private struct SpeckleGrain: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<40 {
                let x = size.width
                    * CGFloat((sin(Double(index) * 12.9898) * 43758.5453)
                        .truncatingRemainder(dividingBy: 1).magnitude)
                let y = size.height
                    * CGFloat((sin(Double(index) * 78.233) * 12345.6789)
                        .truncatingRemainder(dividingBy: 1).magnitude)
                context.fill(
                    Circle().path(in: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                    with: .color(.white.opacity(0.06)))
            }
        }
    }
}

/// Waves (MyWidgetWave): two accent-tinted bands anchored to the bottom.
private var widgetWavePaint: some View {
    ZStack {
        widgetSolidPaint
        WaveShape(phase: 0)
            .fill(Color(white: 0.16))
        WaveShape(phase: 1)
            .fill(WidgetInk.accent.opacity(0.18))
    }
}

// MARK: - Shapes

/// Zigzag torn edge along the shape's bottom, deterministic per tearFraction.
struct TornEdgeShape: Shape {
    var tearFraction: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * CGFloat(1 - tearFraction)))
        // Deterministic paper tear across the middle of the sheet.
        let segments = 7
        for step in 1...segments {
            let stepX = CGFloat(step) / CGFloat(segments) * rect.maxX
            let seed = sin(Double(step) * 4.437) // [-1, 1]
            let stepY = rect.minY + rect.height * CGFloat(1 - tearFraction)
                + rect.height * CGFloat(tearFraction) * CGFloat(0.35 + 0.3 * seed)
            path.addLine(to: CGPoint(x: stepX, y: stepY))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Two-crest wave band anchored to the shape's bottom.
struct WaveShape: Shape {
    /// 0 = wide slower crest, 1 = steeper accent crest (phase/stacking hint).
    var phase: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let crestHeight = rect.height * (phase == 0 ? 0.55 : 0.8)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - crestHeight))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - crestHeight * 0.4),
            control1: CGPoint(x: rect.midX * 0.6, y: rect.maxY - crestHeight * 1.25),
            control2: CGPoint(x: rect.midX * 1.2, y: rect.maxY - crestHeight * (phase == 0 ? -0.05 : 0.6))
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Ticket chrome (MyWidgetTicket) for the counter

/// Stub-perforation line: dashed hairline like a ticket tear-line.
struct TicketPerforation: View {
    var color: Color

    var body: some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 5]))
            .foregroundStyle(color)
            .frame(height: 2)
    }
}
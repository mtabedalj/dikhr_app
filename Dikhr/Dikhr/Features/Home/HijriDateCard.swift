import SwiftUI

// MARK: - Hijri date card
//
// Original ground truth (Main.storyboard header/athkarHeader scenes +
// Localizable.strings date keys):
//   - "تاريخ اليوم بالهجري والميلادي." — the card shows both calendars.
//   - Date layout options in the original include "اسم اليوم + هجري Day + Hijri"
//     (heading style) with a gregorian secondary, e.g.
//     "الجمعة ١٤ ربيع الأول ١٤٤٧ هـ" + "٢٥ أكتوبر ٢٠٢٦ م".
// Calendar: islamicUmmAlQura + the "تعديل التاريخ الهجري" offset
// (SettingsStore.hijriAdjustment, UserDefaults key "hijriAdjustment").

struct HijriDateCard: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 4) {
            // Original heading style: day name + hijri date (Arabic-Indic digits).
            Text(verbatim: settings.t(HomeHijri.arabicLine(for: now, adjustment: settings.hijriAdjustment),
                                      HomeHijri.englishLine(for: now, adjustment: settings.hijriAdjustment)))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(verbatim: HomeHijri.gregorianLine(for: now))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
        .onReceive(timer) { now = $0 }
        .dikhrRefresh(now: $now)
    }
}
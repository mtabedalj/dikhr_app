import SwiftUI

// MARK: - Ramadan countdown card
//
// Original ground truth (Localizable.strings, ar.lproj values quoted verbatim):
//   - "باقي على رمضان" (en: Until Ramadan) — the countdown heading.
//   - "%lld يوم" / "%lld أيام" — day-count templates from the original
//     Localizable.stringsdict.
//   - "رمضان القادم يوافق" (en: Next Ramadan will start on) — the target date.
//   - "رمضان مبارك" — heading while inside Ramadan.
// The original card also lists the two Eids ("رمضان والعيد"); Dikhr exposes the
// Ramadan part, which the storyboard's ramadanDateCard.nib scene presents.

struct RamadanCountdownCard: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if HomeHijri.isRamadan(now: now, adjustment: settings.hijriAdjustment) {
                inRamadanView
            } else if let countdown = HomeHijri.daysUntilRamadan(
                now: now, adjustment: settings.hijriAdjustment), countdown.days > 0 {
                countdownView(countdown)
            } else {
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
        .onReceive(timer) { now = $0 }
        .dikhrRefresh(now: $now)
    }

    private var inRamadanView: some View {
        let day = HomeHijri.components(for: now, adjustment: settings.hijriAdjustment).day
        return VStack(spacing: 6) {
            Text(settings.t("رمضان مبارك", "Blessed Ramadan"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(verbatim: settings.t("اليوم \(HomeCards.arabicDigits(day)) من ٣٠",
                                      "Day \(HomeCards.englishDigits(day)) of 30"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.accent)
                .monospacedDigit()
            Text(verbatim: settings.t("يوم الصيام \(HomeCards.arabicDigits(day))",
                                      "Fasting day \(HomeCards.englishDigits(day))"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func countdownView(_ countdown: (days: Int, target: Date, hijriYear: Int)) -> some View {
        VStack(spacing: 6) {
            Text(settings.t("باقي على رمضان", "Until Ramadan"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(verbatim: settings.t(HomeCards.arabicDays(countdown.days),
                                      HomeCards.englishDays(countdown.days)))
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(.accent)
                .monospacedDigit()
            Text(verbatim: settings.t("رمضان القادم يوافق \(HomeHijri.gregorianLine(for: countdown.target))",
                                      "Next Ramadan falls on \(HomeHijri.gregorianLine(for: countdown.target))"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}
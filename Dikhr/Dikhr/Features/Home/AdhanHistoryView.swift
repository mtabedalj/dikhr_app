import Foundation
import SwiftUI

// MARK: - "مضى على أذان X" history page
//
// Arabic strings are the ones shipped by the original bundle
// (ar.lproj/Localizable.strings — keys are the Arabic values themselves):
//   'مضى على أذان %@ %@ %@'   → "%1$@ Athan %2$@ ago %3$@"
//   'يحين الآن موعد %1$@'      → "It is now the time of %1$@"
//   'الأذان'                   → "Athan"
// Dikhr already uses the same phrasing in AlarmScheduler
// ("مضى على أذان \(label) \(n) دقيقة") — this page extends it to a full
// elapsed-since-athan history for today's prayers.

/// One row of today's athkan history.
struct AthanHistoryRowData: Identifiable {
    let kind: PrayerKind
    let athanDate: Date
    /// Elapsed since athan when past, remaining until athan when upcoming.
    let elapsed: TimeInterval
    /// True while this prayer is the active window (now between this athan and
    /// the next athan time).
    let isCurrent: Bool

    var id: String { kind.rawValue }

    /// "مضى على أذان X Y د" / "يحين الآن موعد X" / "باقي Y د على أذان X"
    var arabicStatus: String {
        if isCurrent {
            return String(format: "يحين الآن موعد %@", kind.arabicName)
        }
        let s = Int(max(0, abs(elapsed)))
        let h = s / 3600
        let m = (s % 3600) / 60
        var duration = ""
        if h > 0 { duration += h > 1 ? "\(h) س و " : "ساعة و " }
        duration += m > 1 ? "\(m) د" : (m == 1 ? "دقيقة" : "أقل من دقيقة")
        if elapsed < 0 {
            return "باقي \(duration) على أذان \(kind.arabicName)"
        }
        return String(format: "مضى على أذان %@ %@", kind.arabicName, duration)
    }

    /// English counterpart of `arabicStatus` for the language switch.
    var englishStatus: String {
        if isCurrent {
            return String(format: "It is now the time of %@", kind.englishName)
        }
        let s = Int(max(0, abs(elapsed)))
        let h = s / 3600
        let m = (s % 3600) / 60
        var duration = ""
        if h > 0 { duration += h > 1 ? "\(h)h " : "1h " }
        duration += m > 1 ? "\(m)m" : (m == 1 ? "1m" : "<1m")
        if elapsed < 0 {
            return "\(kind.englishName) adhan in \(duration)"
        }
        return String(format: "%1$@ adhan was %2$@ ago", kind.englishName, duration)
    }
}

/// "مضى على أذان …" — elapsed-since-athan rows for today's prayers,
/// computed with PrayerTimesEngine through the DikhrShared city/method
/// (same source as the widget so both agree).
struct AdhanHistoryView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var times: PrayerTimes? {
        let method = DikhrMethodLoader.method(id: DikhrShared.methodID)
        let city = DikhrShared.city
        return PrayerTimesEngine.calculate(
            method: method, lat: city.lat, lng: city.lng, date: now, timeZone: .current)
    }

    private var rows: [AthanHistoryRowData] {
        guard let t = times else { return [] }
        let ordered: [(PrayerKind, Date)] = [
            (.fajr, t.fajr), (.sunrise, t.sunrise), (.dhuhr, t.dhuhr),
            (.asr, t.asr), (.maghrib, t.maghrib), (.isha, t.isha)]
        var result: [AthanHistoryRowData] = []
        for (i, item) in ordered.enumerated() {
            let (kind, date) = item
            // The active window is this athan until the next marker (next day's
            // fajr for isha).
            let nextDate = i + 1 < ordered.count ? ordered[i + 1].1 : t.fajr.addingTimeInterval(86_400)
            let isCurrent = now >= date && now < nextDate
            result.append(AthanHistoryRowData(
                kind: kind,
                athanDate: date,
                elapsed: now.timeIntervalSince(date),
                isCurrent: isCurrent))
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if rows.isEmpty {
                    Text(settings.t("تعذّر حساب المواقيت — تأكد من المدينة وطريقة الحساب.",
                                    "Could not calculate prayer times — check your city and calculation method."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                }
                ForEach(rows) { row in
                    AdhanHistoryRow(row: row, now: now)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.t("الأذان", "Adhan"))
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { now = $0 }
    }
}

/// One row: prayer name + athan time on the right (RTL lead), elapsed/now on the left.
struct AdhanHistoryRow: View {
    @EnvironmentObject private var settings: SettingsStore
    let row: AthanHistoryRowData
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.kind.symbol)
                .foregroundStyle(row.isCurrent ? Color.accentColor : Color.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(settings.t(row.kind.arabicName, row.kind.englishName))
                    .font(.headline)
                Text(row.athanDate, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            if row.isCurrent {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.accent)
                        .frame(width: 8, height: 8)
                    Text(settings.t(row.arabicStatus, row.englishStatus))
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                }
            } else {
                Text(settings.t(row.arabicStatus, row.englishStatus))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}
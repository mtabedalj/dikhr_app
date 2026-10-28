import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Flagship prayer widget (the original's MyWidgetFivePrayersElement look)
//
// Dark design, the original's #76D6FF accent, all five prayers listed with the
// next/current highlighted, Arabic digits for Arabic locales, and a live
// "الوقت المتبقي" countdown. Timeline entries land ON each prayer boundary so the
// highlight and the countdown anchor flip exactly at مواقيت الصلاة.

// MARK: - Configuration (editable background — WidgetKit persists the option)

/// The five prayer rows: الشروق is a موقيت, not a صلاة, so the five-prayers
/// element (the original's own layout) skips it.
private let widgetFivePrayers: [PrayerKind] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

struct PrayerWidgetConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "مواقيت الصلاة"
    static let description = IntentDescription(
        "اعرض وقت الصلاة القادمة والعد التنازلي للصلاة أو مواقيت الصلاة. اضغطة مطولة لاختيار الخلفية.")

    @Parameter(title: "الخلفية", default: WidgetBackgroundKind.dark)
    var background: WidgetBackgroundKind
}

// MARK: - Timeline entry

struct FivePrayersEntry: TimelineEntry {
    var date: Date
    var configuration: PrayerWidgetConfigIntent
    var schedule: [(PrayerKind, Date)]
    var nextKind: PrayerKind?
    var nextDate: Date?
    var cityName: String
}

struct FivePrayersProvider: AppIntentTimelineProvider {

    private func daySchedule(for date: Date) -> PrayerTimes {
        let city = DikhrShared.city
        let method = DikhrMethodLoader.method(id: DikhrShared.methodID)
        return PrayerTimesEngine.calculate(method: method, lat: city.lat, lng: city.lng,
                                           date: date, timeZone: .current)
    }

    private func pairs(_ times: PrayerTimes) -> [(PrayerKind, Date)] {
        [(.fajr, times.fajr), (.sunrise, times.sunrise), (.dhuhr, times.dhuhr),
         (.asr, times.asr), (.maghrib, times.maghrib), (.isha, times.isha)]
    }

    private func entry(at date: Date,
                       configuration: PrayerWidgetConfigIntent) -> FivePrayersEntry {
        let calendar = Calendar.current
        let tonight = calendar.startOfDay(for: date)
        // Walk today + two days so isha → fajr rolls over the boundary forever.
        for offset in 0...2 {
            let day = calendar.date(byAdding: .day, value: offset, to: tonight) ?? tonight
            let schedule = pairs(daySchedule(for: day))
            if let next = schedule.first(where: { $0.1 > date }) {
                return FivePrayersEntry(date: date, configuration: configuration,
                                        schedule: schedule, nextKind: next.0, nextDate: next.1,
                                        cityName: DikhrShared.city.name)
            }
        }
        // Unreachable fallback (engine always emits 6 pairs/day).
        let schedule = pairs(daySchedule(for: tonight))
        return FivePrayersEntry(date: date, configuration: configuration,
                                schedule: schedule, nextKind: nil, nextDate: nil,
                                cityName: DikhrShared.city.name)
    }

    func placeholder(in context: Context) -> FivePrayersEntry {
        entry(at: Date(), configuration: PrayerWidgetConfigIntent())
    }

    func snapshot(for configuration: PrayerWidgetConfigIntent, in context: Context) async -> FivePrayersEntry {
        entry(at: Date(), configuration: configuration)
    }

    func timeline(for configuration: PrayerWidgetConfigIntent,
                  in context: Context) async -> Timeline<FivePrayersEntry> {
        var entries: [FivePrayersEntry] = []
        let now = Date()
        // The first entry renders immediately ...
        entries.append(entry(at: now, configuration: configuration))
        // ... then one per prayer boundary: when a boundary passes, the entry AT
        // that instant re-highlights the row and re-anchors the countdown.
        let calendar = Calendar.current
        let tonight = calendar.startOfDay(for: now)
        for offset in 0...2 {
            let day = calendar.date(byAdding: .day, value: offset, to: tonight) ?? tonight
            for (_, boundary) in pairs(daySchedule(for: day)) where boundary > now {
                entries.append(entry(at: boundary, configuration: configuration))
            }
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - View

struct FivePrayersWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: FivePrayersEntry

    /// The five obligatory prayers, preserving the original's row order
    /// (الشروق is a موقيت, not a صلاة — the original's five-prayers element skips it).
    private var visible: [(PrayerKind, Date)] {
        entry.schedule.filter { widgetFivePrayers.contains($0.0) }
    }

    var body: some View {
        Group {
            if family == .systemSmall {
                nextCard
            } else {
                fullBoard
            }
        }
        .padding(10)
        .containerBackgroundCompat(entry.configuration.background)
        .foregroundStyle(.white)
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: small — next prayer card (MyWidgetNextPrayerInk style)

    private var nextCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: entry.nextKind?.symbol ?? "clock")
                    .font(.caption2)
                    .foregroundStyle(WidgetInk.accent)
                Text(entry.cityName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                Spacer()
            }
            Spacer(minLength: 0)
            if let next = entry.nextKind, let date = entry.nextDate {
                Text(next.arabicName)
                    .font(.title3.bold())
                    .foregroundStyle(WidgetInk.accent)
                Text(WidgetLocaleDigits.timeString(date))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                Text("الوقت المتبقي")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                Text(timerInterval: entry.date...date, countsDown: true)
                    .font(.title3.bold())
                    .foregroundStyle(WidgetInk.accent)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: medium+ — all five prayers board

    private var fullBoard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mosque")
                    .font(.caption)
                    .foregroundStyle(WidgetInk.accent)
                Text(entry.cityName)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                Spacer()
                if let kind = entry.nextKind {
                    Image(systemName: kind.symbol)
                        .font(.caption)
                        .foregroundStyle(WidgetInk.accent)
                }
            }
            // The five prayer columns; the next/current one is inked in the accent.
            HStack(spacing: 5) {
                ForEach(visible, id: \.0.id) { kind, date in
                    let isNext = kind == entry.nextKind
                    VStack(spacing: 3) {
                        Text(kind.arabicName)
                            .font(.caption2.bold())
                            .foregroundStyle(isNext ? WidgetInk.accent : .white.opacity(0.55))
                        Text(WidgetLocaleDigits.timeString(date))
                            .font(.footnote)
                            .fontWeight(isNext ? .bold : .regular)
                            .monospacedDigit()
                            .foregroundStyle(isNext ? .white : .white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10,
                                         style: .continuous)
                            .fill(isNext ? WidgetInk.accent.opacity(0.16) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isNext ? WidgetInk.accent.opacity(0.4) : WidgetInk.hairline,
                                          lineWidth: isNext ? 1.5 : 1)
                    )
                }
            }
            // الحدّ الفاصل + الشريط السفلي: الوقت المتبقي
            HStack {
                Text("الوقت المتبقي")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                if let date = entry.nextDate {
                    Text(timerInterval: entry.date...date, countsDown: true)
                        .font(.headline)
                        .foregroundStyle(WidgetInk.accent)
                        .monospacedDigit()
                }
            }
        }
    }
}

struct FivePrayersWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DikhrNextPrayer",
                               intent: PrayerWidgetConfigIntent.self,
                               provider: FivePrayersProvider()) { entry in
            FivePrayersWidgetView(entry: entry)
        }
        .configurationDisplayName("مواقيت الصلاة")
        .description("اعرض وقت الصلاة القادمة والعد التنازلي للصلاة أو مواقيت الصلاة. اضغطة مطولة لاختيار الخلفية.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

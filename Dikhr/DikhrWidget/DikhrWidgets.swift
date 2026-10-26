import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Timeline data

struct PrayerTimelineEntry: TimelineEntry {
    var date: Date
    var times: PrayerTimes
    var cityName: String
    var nextKind: PrayerKind?
    var nextDate: Date?
}

struct PrayerTimelineProvider: TimelineProvider {
    private func entryData(at date: Date) -> PrayerTimelineEntry {
        let city = DikhrShared.city
        let method = DikhrMethodLoader.method(id: DikhrShared.methodID)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let list: [PrayerKind] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]

        for dayOffset in [0, 1] {
            let day = (calendar.date(byAdding: .day, value: dayOffset, to: today)) ?? today
            let t = PrayerTimesEngine.calculate(method: method, lat: city.lat, lng: city.lng, date: day, timeZone: .current)
            let pairs: [(PrayerKind, Date)] = [(.fajr, t.fajr), (.sunrise, t.sunrise), (.dhuhr, t.dhuhr),
                                               (.asr, t.asr), (.maghrib, t.maghrib), (.isha, t.isha)]
            if let next = pairs.first(where: { $0.1 > date }) {
                return PrayerTimelineEntry(date: date, times: t, cityName: city.name, nextKind: next.0, nextDate: next.1)
            }
        }
        // Fallback (should not happen): today's schedule
        let t = PrayerTimesEngine.calculate(method: method, lat: city.lat, lng: city.lng, date: today, timeZone: .current)
        return PrayerTimelineEntry(date: date, times: t, cityName: city.name)
    }

    func placeholder(in context: Context) -> PrayerTimelineEntry {
        entryData(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerTimelineEntry) -> Void) {
        completion(entryData(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimelineEntry>) -> Void) {
        var entries: [PrayerTimelineEntry] = []
        var cursor = Date()
        let end = cursor.addingTimeInterval(60 * 60 * 24)
        while cursor < end {
            entries.append(entryData(at: cursor))
            cursor = cursor.addingTimeInterval(60 * 30)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Next prayer widget

struct PrayerTimesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PrayerTimelineEntry

    private var schedule: [(kind: PrayerKind, date: Date)] {
        let t = entry.times
        return [(kind: .fajr, date: t.fajr), (kind: .sunrise, date: t.sunrise), (kind: .dhuhr, date: t.dhuhr),
                (kind: .asr, date: t.asr), (kind: .maghrib, date: t.maghrib), (kind: .isha, date: t.isha)]
    }

    private var next: (PrayerKind, Date)? {
        guard let kind = entry.nextKind, let date = entry.nextDate else { return nil }
        return (kind, date)
    }

    var body: some View {
        Group {
            if family == .systemSmall {
                smallView
            } else {
                mediumView
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.cityName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let next {
                Text(next.0.arabicName)
                    .font(.headline)
                    .foregroundStyle(.tint)
                Text(next.1, format: .dateTime.hour().minute())
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(timerInterval: entry.date...next.1, countsDown: true, showsHours: true)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.cityName)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if let next {
                    Text("القادمة: \(next.0.arabicName)")
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                }
            }
            HStack(spacing: 6) {
                ForEach(schedule, id: \.kind.id) { item in
                    let kind = item.kind; let date = item.date
                    VStack(spacing: 3) {
                        Text(kind.arabicName)
                            .font(.caption2)
                            .foregroundStyle(next?.0 == kind ? Color.accentColor : Color.secondary)
                        Text(date, format: .dateTime.hour().minute())
                            .font(.caption.monospacedDigit())
                            .fontWeight(next?.0 == kind ? .bold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
    }
}

struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DikhrNextPrayer", provider: PrayerTimelineProvider()) { entry in
            PrayerTimesWidgetView(entry: entry)
        }
        .configurationDisplayName("مواقيت الصلاة")
        .description("اعرض الصلاة القادمة أو جميع المواقيت")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Counter widget (interactive)

struct CounterSnapshot: Codable, TimelineEntry {
    var date: Date
    var count: Int
    var name: String
    var target: Int
}

struct CounterProvider: TimelineProvider {
    func entry(at date: Date) -> CounterSnapshot {
        let first = DikhrShared.loadCounters().first
        return CounterSnapshot(date: date, count: first?.count ?? 0, name: first?.name ?? "سبحان الله", target: first?.target ?? 0)
    }

    func placeholder(in context: Context) -> CounterSnapshot { entry(at: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (CounterSnapshot) -> Void) {
        completion(entry(at: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CounterSnapshot>) -> Void) {
        completion(Timeline(entries: [entry(at: Date())], policy: .never))
    }
}

struct CounterWidgetView: View {
    var entry: CounterSnapshot

    var body: some View {
        VStack(spacing: 8) {
            Text(entry.name)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(entry.count)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
            Button(intent: IncrementCounterIntent()) {
                Label("عدّ", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .tint(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.tint))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct CounterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DikhrCounter", provider: CounterProvider()) { entry in
            CounterWidgetView(entry: entry)
        }
        .configurationDisplayName("العداد")
        .description("سبّح مباشرة من الشاشة الرئيسية")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Bundle

@main
struct DikhrWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
        CounterWidget()
        CounterLiveActivity()
    }
}
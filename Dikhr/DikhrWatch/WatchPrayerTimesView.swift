import SwiftUI

/// Prayer times page for the watch. Parity with the original watch app:
/// list of the five prayers, Jumu'ah name replaces Dhuhr on Fridays
/// (original: "يظهر اسم الجمعة بدل الظهر يوم الجمعة فقط"), next prayer
/// highlighted with a countdown, and a location/method header.
struct WatchPrayerTimesView: View {
    @State private var times: PrayerTimes?
    @State private var city = DikhrShared.city
    @State private var now = Date()
    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private struct Row {
        let name: String
        let date: Date
        var isNext = false
        var isPast = false
    }

    private func rows() -> [Row] {
        guard let t = times else { return [] }
        var list = [
            Row(name: prayerName("الفجر"), date: t.fajr),
            Row(name: prayerName("الشروق"), date: t.sunrise),
            Row(name: prayerName("الظهر"), date: t.dhuhr),
            Row(name: prayerName("العصر"), date: t.asr),
            Row(name: prayerName("المغرب"), date: t.maghrib),
            Row(name: prayerName("العشاء"), date: t.isha),
        ]
        if let nextIdx = list.firstIndex(where: { $0.date > now }) {
            list[nextIdx].isNext = true
        }
        for idx in list.indices {
            list[idx].isPast = list[idx].date < now && !list[idx].isNext
        }
        return list
    }

    /// Friday-only Jumu'ah label, matching the original toggle behavior.
    private func prayerName(_ base: String) -> String {
        guard base == "الظهر",
              Calendar.current.component(.weekday, from: now) == 6 else { return base }
        return "الجمعة"
    }

    private var nextRow: Row? { rows().first(where: { $0.isNext }) }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if nextRow != nil {
                    headerView
                    ForEach(rows(), id: \.date) { row in
                        prayerRow(row)
                    }
                } else {
                    emptyView
                }
            }
            .padding(.horizontal, 8)
        }
        .onAppear(perform: compute)
        .onReceive(timer) { date in
            now = date
        }
    }

    private var headerView: some View {
        VStack(spacing: 2) {
            Text(city.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let next = nextRow {
                Text(countdown(to: next.date))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WatchTheme.accent)
                Text("حتى \(next.name)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    private func prayerRow(_ row: Row) -> some View {
        HStack {
            Text(row.name)
                .font(row.isNext ? .footnote.bold() : .footnote)
            Spacer()
            Text(row.date, format: .dateTime.hour().minute())
                .font(.footnote.bold())
                .monospacedDigit()
                .foregroundStyle(row.isNext ? WatchTheme.accent
                                 : row.isPast ? Color.secondary.opacity(0.6)
                                 : WatchTheme.prayerGreen)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, row.isNext ? 6 : 0)
        .background(row.isNext ? WatchTheme.accent.opacity(0.14) : .clear)
        .cornerRadius(8)
    }

    private var emptyView: some View {
        Text("فعّل مواقيت الصلاة في الأيفون لتظهر هنا")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compute() {
        now = Date()
        city = DikhrShared.city
        let method = DikhrMethodLoader.method(id: DikhrShared.methodID)
        times = PrayerTimesEngine.calculate(method: method, lat: city.lat, lng: city.lng, date: now, timeZone: .current)
    }

    private func countdown(to date: Date) -> String {
        let interval = max(0, date.timeIntervalSince(now))
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
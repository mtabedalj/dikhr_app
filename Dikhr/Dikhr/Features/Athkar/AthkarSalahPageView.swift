import SwiftUI

// MARK: - الصلاة chip page (full-screen dark prayer screen from the chip row)
//
// Live capture ground truth (/tmp/athkar_live_5b.png — a macOS capture of the
// REAL app, laid out left-to-right):
//   - pure black screen, no nav bar
//   - top-left: small cream moon disc with a soft glow
//   - top-right: dark circular back button with a right chevron (dismiss)
//   - "الوقت الآن" centered + big bold 24h clock "2:01:49" ticking each second
//   - tiny gray "…" under the clock
//   - right edge: thin (~6pt) rounded vertical progress bar spanning the
//     screen height: light-gray fill top→down for the elapsed fraction
//     (now − previous prayer) / (next prayer − previous prayer), darker below
//   - previous prayer block (name + "7:51 م") sits left of the bar's top
//   - next prayer block (name + "6:42 ص") sits left of the bar's bottom
//   - bottom-left: big gold countdown HH:MM:SS to the next prayer
//   - bottom row: "1448-05-16" (hijri yyyy-mm-dd) left, "…" center,
//     city name ("ديبورن هايتس") right
// The capture's own coordinate space is pinned with a forced leftToRight
// layout direction so the screen matches it under any device language.
struct AthkarSalahPageView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var now = Date()

    private let tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let gold = Color(red: 0.79, green: 0.65, blue: 0.35)

    private var times: PrayerTimes? {
        HomeCards.resolveTimes(settings: settings, now: now)
    }

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.024).ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                timeBlock
                intervalZone
                    .frame(maxHeight: .infinity)
                    .padding(.top, 4)
                bottomZone
            }
            .padding(.top, 4)
        }
        .environment(\.layoutDirection, .leftToRight)
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(tickTimer) { now = $0 }
    }

    // MARK: top bar — moon + back chevron

    private var topBar: some View {
        HStack {
            moonDisc
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 44)
    }

    /// Cream moon: shaded disc + soft outer glow (capture shows a bloom on
    /// its lower-left edge).
    private var moonDisc: some View {
        Circle()
            .fill(LinearGradient(colors: [Color(red: 0.97, green: 0.94, blue: 0.86),
                                         Color(red: 0.80, green: 0.73, blue: 0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 24, height: 24)
            .shadow(color: Color(red: 0.92, green: 0.85, blue: 0.62).opacity(0.55),
                    radius: 9, x: -3, y: 3)
    }

    // MARK: current time block

    private var timeBlock: some View {
        VStack(spacing: 6) {
            Text(settings.t("الوقت الآن", "Current time"))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            let c = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
            Text(String(format: "%d:%02d:%02d", c.hour ?? 0, c.minute ?? 0, c.second ?? 0))
                .font(.system(size: 38, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("…")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.top, 10)
    }

    // MARK: prayer interval (previous/next + progress column)

    private var intervalZone: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                // Thin rounded progress column filling the zone height:
                // light elapsed fill grows from the top, darker track below.
                VStack {
                    let frac = min(max(elapsedFraction, 0), 1)
                    ZStack(alignment: .top) {
                        Capsule().fill(Color(white: 0.13))
                            .frame(width: 6, height: geo.size.height)
                        Capsule().fill(Color(white: 0.72))
                            .frame(width: 6, height: max(6, geo.size.height * frac))
                    }
                }
                .frame(maxHeight: .infinity)

                VStack {
                    // Previous prayer (the interval we are in), upper right.
                    HStack(alignment: .top) {
                        Spacer()
                        if let prev = intervalPrayer.prev {
                            prayerLabel(prev.kind, prev.date)
                        }
                    }
                    .padding(.trailing, 20)
                    Spacer()
                    // Next prayer, lower right.
                    HStack(alignment: .bottom) {
                        Spacer()
                        if let next = intervalPrayer.next {
                            prayerLabel(next.kind, next.date)
                        }
                    }
                    .padding(.trailing, 20)
                }
                .frame(height: geo.size.height)
            }
        }
    }

    private func prayerLabel(_ kind: PrayerKind, _ date: Date) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(settings.t(kind.arabicName, kind.englishName))
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white)
            let twelve = twelveHour(date)
            Text("\(twelve.time) \(twelve.suffix)")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }

    private struct PrayerEvent: Equatable {
        let kind: PrayerKind
        let date: Date
    }

    /// Prayers only (sunrise excluded) for one civil day.
    private func events(on date: Date) -> [PrayerEvent] {
        guard let method = HomeCards.resolveMethod(settings: settings) else { return [] }
        let t = PrayerTimesEngine.calculate(method: method, lat: settings.currentCity.lat,
                                            lng: settings.currentCity.lng,
                                            date: date, timeZone: .current)
        return [PrayerEvent(kind: .fajr, date: t.fajr),
                PrayerEvent(kind: .dhuhr, date: t.dhuhr),
                PrayerEvent(kind: .asr, date: t.asr),
                PrayerEvent(kind: .maghrib, date: t.maghrib),
                PrayerEvent(kind: .isha, date: t.isha)]
    }

    /// Previous (most recent past) and next (first upcoming) prayer around
    /// now — spans yesterday/today/tomorrow so late-night hours resolve to
    /// yesterday's isha → today's fajr (matches the capture at 2:01 AM).
    private var intervalPrayer: (prev: PrayerEvent?, next: PrayerEvent?) {
        let cal = Calendar.current
        var all = events(on: cal.date(byAdding: .day, value: -1, to: now) ?? now)
        all += events(on: now)
        all += events(on: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        return (all.last { $0.date <= now }, all.first { $0.date > now })
    }

    /// Elapsed fraction of the interval between prayers (bar fill top→down).
    private var elapsedFraction: Double {
        guard let prev = intervalPrayer.prev, let next = intervalPrayer.next else { return 0 }
        let span = next.date.timeIntervalSince(prev.date)
        guard span > 0 else { return 0 }
        return now.timeIntervalSince(prev.date) / span
    }

    /// 12h "7:51" + "م"/"ص" suffix (Western digits, matching the capture).
    private func twelveHour(_ date: Date) -> (time: String, suffix: String) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h24 = c.hour ?? 0
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return (String(format: "%d:%02d", h12, c.minute ?? 0), h24 < 12 ? "ص" : "م")
    }

    // MARK: bottom — gold countdown + info row

    private var bottomZone: some View {
        VStack(spacing: 8) {
            HStack {
                if let next = intervalPrayer.next {
                    let s = max(0, Int(next.date.timeIntervalSince(now)))
                    Text(String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60))
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(gold)
                }
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.bottom, 6)

            bottomInfoRow
        }
    }

    private var bottomInfoRow: some View {
        let h = HomeHijri.components(for: now, adjustment: settings.hijriAdjustment)
        return HStack(alignment: .center) {
            Text(String(format: "%04d-%02d-%02d", h.year, h.month, h.day))
                .font(.system(size: 15))
                .monospacedDigit()
                .foregroundStyle(.white)
            Spacer()
            Text("…")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text(settings.cityName(settings.currentCity))
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }
}
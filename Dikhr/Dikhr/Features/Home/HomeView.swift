import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var now = Date()
    @State private var showQibla = false

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var times: PrayerTimes? {
        guard let method = SettingsStore.loadMethods().first(where: { $0.id == settings.methodID })
        else { return nil }
        return PrayerTimesEngine.calculate(
            method: method, lat: settings.currentCity.lat, lng: settings.currentCity.lng,
            date: now, timeZone: .current)
    }

    private var next: (kind: PrayerKind, date: Date)? {
        guard let t = times else { return nil }
        let upcoming: [(PrayerKind, Date)] = [
            (.fajr, t.fajr), (.sunrise, t.sunrise), (.dhuhr, t.dhuhr),
            (.asr, t.asr), (.maghrib, t.maghrib), (.isha, t.isha)]
        return upcoming.first(where: { $0.1 > now })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HeaderAudioBar()
                    HijriDateCard()
                    RamadanCountdownCard()
                    DailyAyahCard()
                    TimeMomentsCard()
                    FridayCard()
                    DuhaCard()
                    countdownCard
                    timesCard
                    StreaksCard()
                    dailyCard
                    NavigationLink {
                        AdhanHistoryView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge")
                                .font(.title3)
                                .foregroundStyle(.accent)
                            Text(settings.t("مضى على الأذان", "Latest Adhan"))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.left")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
                    }
                    .buttonStyle(.plain)
                    qiyamCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(settings.isUsingDeviceLocation
                             ? "📍 \(settings.cityName(settings.currentCity))"
                             : settings.cityName(settings.city))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        QiblaView()
                    } label: {
                        Image(systemName: "safari.fill")
                            .font(.headline)
                    }
                }
            }
            .onReceive(timer) { now = $0 }
            .onAppear {
                if ProcessInfo.processInfo.environment["DIKHR_QIBLA"] != nil {
                    showQibla = true
                }
            }
            .navigationDestination(isPresented: $showQibla) {
                QiblaView()
            }
        }
    }

    private var countdownCard: some View {
        VStack(spacing: 6) {
            if let next {
                Text(settings.t("الصلاة القادمة", "Next Prayer"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(settings.t(next.kind.arabicName, next.kind.englishName))
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(.accent)
                Text(next.date, format: .dateTime.hour().minute())
                    .font(.title2)
                    .monospacedDigit()
                Text("\(remainingText(until: next.date))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if let times {
                Text(settings.t("الفجر", "Fajr"))
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(.accent)
                Text(times.fajr, format: .dateTime.hour().minute())
                    .font(.title2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var timesCard: some View {
        VStack(spacing: 0) {
            if let t = times {
                timeRow(PrayerKind.fajr, t.fajr)
                Divider()
                timeRow(PrayerKind.sunrise, t.sunrise)
                Divider()
                timeRow(PrayerKind.dhuhr, t.dhuhr)
                Divider()
                timeRow(PrayerKind.asr, t.asr)
                Divider()
                timeRow(PrayerKind.maghrib, t.maghrib)
                Divider()
                timeRow(PrayerKind.isha, t.isha)
            }
        }
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var dailyCard: some View {
        NavigationLink {
            DailyView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.t("أدعية اليوم", "Daily Supplications"))
                        .font(.headline)
                    Text(settings.t("مقال من المحتوى اليومي", "From the daily content"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }

    private var qiyamCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(settings.t("ثلث الليل الأخير (قيام)", "Last Third of the Night (Qiyam)"), systemImage: "moon.stars")
                .font(.headline)
            if let t = times {
                Text(t.qiyamStart, format: .dateTime.hour().minute())
                    .font(.title3).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func timeRow(_ kind: PrayerKind, _ date: Date) -> some View {
        HStack {
            Image(systemName: kind.symbol)
                .foregroundStyle(.accent)
                .frame(width: 30)
            Text(settings.t(kind.arabicName, kind.englishName))
                .font(.title3)
            Spacer()
            Text(date, format: .dateTime.hour().minute())
                .font(.title3).monospacedDigit().bold()
            if next?.kind == kind {
                Image(systemName: "chevron.left.2")
                    .foregroundStyle(.accent)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal)
    }

    private func remainingText(until date: Date) -> String {
        let s = Int(date.timeIntervalSince(now))
        guard s > 0 else { return settings.t("الآن", "Now") }
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return settings.t("باقي \(h) س و \(m) د", "\(h)h \(m)m left") }
        return settings.t("باقي \(m) د", "\(m)m left")
    }
}
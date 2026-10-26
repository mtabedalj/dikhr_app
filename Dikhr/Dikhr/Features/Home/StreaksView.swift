import SwiftUI

// MARK: - Streaks
//
// Original ground truth (binary strings): FOUR streaks —
//   "مداومة الصلوات Prayer Streak" / "مداومة الأذكار Athkar Streak" /
//   "مداومة القرآن Quran Streak" / "مداومة النوافل Nawafil Streak"
// each with current + best ("Longest streak of all prayers completed",
// "Shows progress ring with current and best streak",
// dailyTasks_currentStreak/bestStreak + dailyTasks_athkar|quran|nawafilStreakCurrent/Best).

struct StreaksCard: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var prayersStreak = 0
    @State private var athkarStreak = 0
    @State private var quranStreak = 0
    @State private var nawafilStreak = 0
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    streakTile(settings.t("مداومة الصلوات", "Prayer Streak"), streak: prayersStreak, symbol: "flame")
                    streakTile(settings.t("مداومة الأذكار", "Athkar Streak"), streak: athkarStreak, symbol: "flame.fill")
                }
                HStack(spacing: 12) {
                    streakTile(settings.t("مداومة القرآن", "Quran Streak"), streak: quranStreak, symbol: "flame")
                    streakTile(settings.t("مداومة النوافل", "Nawafil Streak"), streak: nawafilStreak, symbol: "star.leadinghalf.filled")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            StreaksDetailView()
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("dikhr-checkin-changed"))) { _ in
            refresh()
        }
    }

    private func refresh() {
        prayersStreak = StreaksStore.streak(for: \.prayers)
        athkarStreak = StreaksStore.athkarStreak()
        quranStreak = StreaksStore.streak(for: \.quran)
        nawafilStreak = StreaksStore.nawafilStreak()
    }

    private func streakTile(_ title: String, streak: Int, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(streak > 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
            Text("\(streak)")
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StreaksDetailView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var day = StreaksStore.today()
    @State private var prayersStreak = 0
    @State private var athkarStreak = 0
    @State private var quranStreak = 0
    @State private var nawafilStreak = 0
    @State private var prayersBest = 0
    @State private var athkarBest = 0
    @State private var quranBest = 0
    @State private var nawafilBest = 0

    var body: some View {
        NavigationStack {
            Form {
                Section(settings.t("اليوم", "Today")) {
                    Toggle(settings.t("صلّيت جميع الصلوات المفروضة", "Prayed all obligatory prayers"), isOn: Binding(
                        get: { day.prayers },
                        set: { day.prayers = $0; StreaksStore.setPrayers($0); refresh(); notify() }))
                    Toggle(settings.t("قرأت من القرآن", "Read Quran"), isOn: Binding(
                        get: { day.quran },
                        set: { day.quran = $0; StreaksStore.setQuran($0); refresh(); notify() }))
                    Toggle(settings.t("صلّيت النوافل اليوم", "Prayed Nawafil today"), isOn: Binding(
                        get: { day.nawafil },
                        set: { day.nawafil = $0; StreaksStore.setNawafil($0); refresh(); notify() }))
                    HStack {
                        Text(settings.t("عدد الأذكار اليوم", "Daily athkar count"))
                        Spacer()
                        Text("\(day.athkarCount)")
                            .monospacedDigit().bold()
                        Button {
                            StreaksStore.addAthkar(1)
                            day = StreaksStore.today()
                            refresh()
                            notify()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Section(settings.t("المداومة", "Streaks")) {
                    streakRow(settings.t("الصلوات", "Prayers"), systemImage: "flame", current: prayersStreak, best: prayersBest)
                    streakRow(settings.t("الأذكار", "Athkar"), systemImage: "flame.fill", current: athkarStreak, best: athkarBest)
                    streakRow(settings.t("القرآن", "Quran"), systemImage: "flame", current: quranStreak, best: quranBest)
                    streakRow(settings.t("النوافل", "Nawafil"), systemImage: "star.leadinghalf.filled", current: nawafilStreak, best: nawafilBest)
                }
            }
            .navigationTitle(settings.t("المداومة", "Streaks"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(settings.t("تم", "Done")) { dismiss() } }
            }
            .onAppear(perform: refresh)
        }
    }

    private func streakRow(_ title: String, systemImage: String, current: Int, best: Int) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)
            Spacer()
            Text(verbatim: settings.t("الحالي \(current) • الأفضل \(best)",
                                      "Current \(current) • Best \(best)"))
                .monospacedDigit()
                .bold()
                .foregroundStyle(.secondary)
        }
    }

    private func refresh() {
        prayersStreak = StreaksStore.streak(for: \.prayers)
        athkarStreak = StreaksStore.athkarStreak()
        quranStreak = StreaksStore.streak(for: \.quran)
        nawafilStreak = StreaksStore.nawafilStreak()
        prayersBest = StreaksStore.bestFor(field: \.prayers)
        athkarBest = StreaksStore.athkarBest()
        quranBest = StreaksStore.bestFor(field: \.quran)
        nawafilBest = StreaksStore.bestFor(field: \.nawafil)
        day = StreaksStore.today()
    }

    private func notify() {
        NotificationCenter.default.post(name: NSNotification.Name("dikhr-checkin-changed"), object: nil)
    }
}
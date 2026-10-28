import SwiftUI
import UIKit

// MARK: - المتابعة والعداد chip page (Progress & Counter)
//
// Evidence: the real Athkar app's العداد chip opens a page titled
// "المتابعة والعداد" — one screen combining:
//   1. المتابعة — the worship-tracker card ("متابعة العبادات" + تجريبي badge,
//      gold % ring over StreaksStore.today(): prayers / quran / nawafil /
//      athkar-day) plus the FOUR streak tiles (prayers, athkar, quran,
//      nawafil) with current + best.
//   2. العداد — a compact counter quick area wired to the SAME
//      CounterStore increment path as CounterView (save + "counter-changed"
//      notification for the Live Activity), long-press-3s reset included,
//      plus a row into the full counter ("الحاسبة الكاملة").
// Dark-first styling like AthkarFavoritesView / AthkarSalahPageView.

private let athkarFollowupGold = Color(red: 0.79, green: 0.65, blue: 0.35)

struct AthkarFollowupView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    // Worship tracker (same fields as the athkar home's mutabaatCard).
    @State private var ringRatio: Double = 0
    @State private var day = StreaksStore.today()

    // Streak data (same lookups as StreaksCard/StreaksDetailView).
    @State private var prayersStreak = 0
    @State private var athkarStreak = 0
    @State private var quranStreak = 0
    @State private var nawafilStreak = 0
    @State private var prayersBest = 0
    @State private var athkarBest = 0
    @State private var quranBest = 0
    @State private var nawafilBest = 0

    // Counter (same store as CounterView; mirrors its first counter).
    @State private var counters: [SavedCounter] = CounterStore.load()

    private var current: SavedCounter? { counters.first }

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.024).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    topBar
                    trackerCard
                    streakTiles
                    counterCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(
            for: NSNotification.Name("dikhr-checkin-changed"))) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(
            for: NSNotification.Name("dikhr-counter-changed"))) { _ in
            counters = CounterStore.load()
        }
    }

    // MARK: top bar — centered title + round back chevron (salah-page style)

    private var topBar: some View {
        ZStack(alignment: .top) {
            HStack {
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
            .padding(.top, 52)
            Text(settings.t("المتابعة والعداد", "Progress & Counter"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 52)
        }
    }

    // MARK: section 1a — worship tracker card (copied from the athkar home)

    private var trackerCard: some View {
        HStack(spacing: 14) {
            ring
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(settings.t("متابعة العبادات", "Worship Tracker"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(settings.t("تجريبي", "Beta"))
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                }
                Text(settings.t("تتبع صلواتك وأذكارك ونوافلك",
                                "Track your prayers, athkar and nawafil"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22)
            .fill(Color(red: 0.055, green: 0.055, blue: 0.062)))
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.16), lineWidth: 5)
            Circle()
                .trim(from: 0, to: ringRatio)
                .stroke(athkarFollowupGold, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(ringRatio * 100))%")
                .font(.footnote.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: 62, height: 62)
    }

    // MARK: section 1b — compact 4-tile streak row

    private var streakTiles: some View {
        HStack(spacing: 10) {
            streakTile(settings.t("الصلوات", "Prayers"), streak: prayersStreak,
                       best: prayersBest, symbol: "flame")
            streakTile(settings.t("الأذكار", "Athkar"), streak: athkarStreak,
                       best: athkarBest, symbol: "flame.fill")
            streakTile(settings.t("القرآن", "Quran"), streak: quranStreak,
                       best: quranBest, symbol: "flame")
            streakTile(settings.t("النوافل", "Nawafil"), streak: nawafilStreak,
                       best: nawafilBest, symbol: "star.leadinghalf.filled")
        }
    }

    private func streakTile(_ title: String, streak: Int, best: Int,
                            symbol: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(streak > 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(.white.opacity(0.35)))
            Text("\(streak)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(settings.t(title, title))
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(settings.t("الأفضل \(best)", "Best \(best)"))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(red: 0.055, green: 0.055, blue: 0.062)))
    }

    // MARK: section 2 — counter quick area (CounterView's language, compact)

    private var counterCard: some View {
        VStack(spacing: 14) {
            if let counter = current {
                HStack(spacing: 16) {
                    progressRing(counter)
                    VStack(spacing: 4) {
                        Text(counter.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(counter.count)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(counter.target > 0
                             ? settings.t("من \(counter.target)", "of \(counter.target)")
                             : settings.t("حرة", "Free"))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    tapButton(counter)
                }
            } else {
                Text(settings.t("لا عدادات بعد", "No counters yet"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 12) {
                // Same reset path as CounterView (long-press 3s + button).
                Button {
                    resetCounter()
                } label: {
                    Label(settings.t("تصفير", "Reset"), systemImage: "arrow.counterclockwise")
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .disabled(current?.count == 0)
                .opacity((current?.count ?? 0) == 0 ? 0.5 : 1)

                NavigationLink {
                    CounterView()
                } label: {
                    HStack(spacing: 6) {
                        Text(settings.t("الحاسبة الكاملة", "Open full counter"))
                            .font(.callout.bold())
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(athkarFollowupGold.opacity(0.16)))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22)
            .fill(Color(red: 0.055, green: 0.055, blue: 0.062)))
    }

    /// Progress ring around the big count (CounterView's visual language).
    private func progressRing(_ counter: SavedCounter) -> some View {
        ZStack {
            Circle().stroke(Color.accentColor.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress(counter))
                .stroke(Color.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.15), value: counter.count)
        }
        .frame(width: 96, height: 96)
        .contentShape(Circle())
        .onTapGesture { increment() }
        // Original evidence: 'للتصفير اضغط مطولًا ٣ ثوان'
        .onLongPressGesture(minimumDuration: 3) {
            resetCounter()
        }
    }

    /// Large round tap-to-increment button (CounterView's + plus haptics).
    private func tapButton(_ counter: SavedCounter) -> some View {
        Button {
            increment()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Circle().fill(Color.accent))
        }
        .buttonStyle(.plain)
    }

    // MARK: logic — CounterView's exact increment path

    private func progress(_ counter: SavedCounter) -> CGFloat {
        guard counter.target > 0 else { return 0 }
        return CGFloat(min(counter.count, counter.target)) / CGFloat(counter.target)
    }

    private func increment() {
        guard let counter = current else { return }
        withAnimation(.spring(duration: 0.2)) { setCount(counter, counter.count + 1) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Long-press (3s) or تصفير: back to zero with the warning haptic,
    /// same as CounterView's reset.
    private func resetCounter() {
        guard let counter = current, counter.count != 0 else { return }
        withAnimation { setCount(counter, 0) }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Persisted through the shared CounterStore + "dikhr-counter-changed"
    /// notification (LiveCounterManager / widget mirror), exactly like CounterView.
    private func setCount(_ counter: SavedCounter, _ value: Int) {
        guard let idx = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        counters[idx].count = value
        CounterStore.save(counters)
        NotificationCenter.default.post(name: Notification.Name("dikhr-counter-changed"), object: nil)
    }

    // MARK: refresh (home's refreshRing + StreaksDetailView's lookups)

    private func refresh() {
        let day = StreaksStore.today()
        let done = [day.prayers, day.quran, day.nawafil, day.athkarCount > 0]
            .filter { $0 }.count
        ringRatio = Double(done) / 4.0
        self.day = day
        prayersStreak = StreaksStore.streak(for: \.prayers)
        athkarStreak = StreaksStore.athkarStreak()
        quranStreak = StreaksStore.streak(for: \.quran)
        nawafilStreak = StreaksStore.nawafilStreak()
        prayersBest = StreaksStore.bestFor(field: \.prayers)
        athkarBest = StreaksStore.athkarBest()
        quranBest = StreaksStore.bestFor(field: \.quran)
        nawafilBest = StreaksStore.bestFor(field: \.nawafil)
        counters = CounterStore.load()
    }
}
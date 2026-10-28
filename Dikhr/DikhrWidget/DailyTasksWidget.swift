import SwiftUI
import WidgetKit
import AppIntents

// MARK: - The athkar task-progress widget (the original's MyWidgetTaskProgressElement)
//
// A متابعة العبادات board: today's prayers / Quran / nawafil / athkar check-ins from
// the app-group streak mirror, a day ring (done of 4, the app's own ratio), live
// streak lines, and the same 3 selectable backgrounds as the prayers widget.
// Data flows: app StreaksStore → DikhrStreaksBridge.mirror (app group) → here.

struct DailyTasksConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "مهام اليوم"
    static let description = IntentDescription(
        "متابعة العبادات: تقدّم أذكار اليوم وقراءته والصلوات، مع المداومة. اضغطة مطولة لاختيار الخلفية.")

    @Parameter(title: "الخلفية", default: WidgetBackgroundKind.dark)
    var background: WidgetBackgroundKind
}

struct DailyTasksEntry: TimelineEntry {
    var date: Date
    var configuration: DailyTasksConfigIntent
    // placeholder-free; check-in data lives in `day`
    var day: DikhrWidgetDayState
}

/// Plain values decoded from the mirrored streaks so the entry is snapshot-safe.
struct DikhrWidgetDayState {
    var prayers: Bool
    var quran: Bool
    var nawafil: Bool
    var athkarCount: Int
    var dayRatio: Double
    var prayersStreak: Int
    var athkarStreak: Int
    var quranStreak: Int
}

struct DailyTasksProvider: AppIntentTimelineProvider {
    private func state(at date: Date) -> DikhrWidgetDayState {
        DikhrWidgetDayState(
            prayers: DikhrStreaksBridge.today(on: date).prayers,
            quran: DikhrStreaksBridge.today(on: date).quran,
            nawafil: DikhrStreaksBridge.today(on: date).nawafil,
            athkarCount: DikhrStreaksBridge.today(on: date).athkarCount,
            dayRatio: DikhrStreaksBridge.dayRatio(on: date),
            prayersStreak: DikhrStreaksBridge.streak(field: \.prayers, from: date),
            athkarStreak: DikhrStreaksBridge.athkarStreak(from: date),
            quranStreak: DikhrStreaksBridge.streak(field: \.quran, from: date))
    }

    private func entry(at date: Date, configuration: DailyTasksConfigIntent) -> DailyTasksEntry {
        DailyTasksEntry(date: date, configuration: configuration, day: state(at: date))
    }

    func placeholder(in context: Context) -> DailyTasksEntry {
        entry(at: Date(), configuration: DailyTasksConfigIntent())
    }

    func snapshot(for configuration: DailyTasksConfigIntent, in context: Context) async -> DailyTasksEntry {
        entry(at: Date(), configuration: configuration)
    }

    func timeline(for configuration: DailyTasksConfigIntent,
                  in context: Context) async -> Timeline<DailyTasksEntry> {
        let now = Date()
        var entries = [entry(at: now, configuration: configuration)]
        // Refresh every 30 minutes while the day is incomplete (athkar ticks up
        // through the day; checked-in items flip the ring), then hold until midnight.
        if !DikhrShared.mirroredDayComplete() {
            entries.append(entry(at: now.addingTimeInterval(30 * 60), configuration: configuration))
        }
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        return Timeline(entries: entries, policy: .after(midnight))
    }
}

extension DikhrShared {
    /// All four of today's mirrored check-ins done → the day ring is full and the
    /// timeline can hold until midnight instead of re-reading the mirror.
    static func mirroredDayComplete() -> Bool {
        DikhrStreaksBridge.dayRatio() >= 1.0
    }
}

// MARK: - View

struct DailyTasksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DailyTasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.caption)
                    .foregroundStyle(WidgetInk.accent)
                Text("متابعة العبادات")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            HStack(spacing: 12) {
                // اليوم: done-of-4 ring (the app's own متابعة ratio)
                ring(progress: entry.day.dayRatio,
                     center: Text("\(WidgetLocaleDigits.apply(String(Int(entry.day.dayRatio * 100))))")
                         .font(.body.bold())
                         .foregroundStyle(WidgetInk.accent))
                VStack(alignment: .leading, spacing: 5) {
                    taskRow(symbol: "sunset.fill", label: "الصلوات", done: entry.day.prayers)
                    taskRow(symbol: "book.closed", label: "القرآن", done: entry.day.quran)
                    taskRow(symbol: "moon.stars.fill", label: "النوافل", done: entry.day.nawafil)
                    HStack(spacing: 5) {
                        Image(systemName: "star.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(entry.day.athkarCount > 0 ? WidgetInk.accent : .white.opacity(0.35))
                        Text("الأذكار · \(WidgetLocaleDigits.apply(String(entry.day.athkarCount)))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                Spacer()
            }
            Spacer(minLength: 0)
            // المداومة line, the same "X أيام متتالية" phrasing the original uses.
            if entry.day.prayersStreak > 0 || entry.day.athkarStreak > 0 {
                Text("مداومة \(WidgetLocaleDigits.apply(String(leadingStreak()))) أيام متتالية")
                    .font(.caption2)
                    .foregroundStyle(WidgetInk.accent.opacity(0.9))
            }
        }
        .padding(12)
        .containerBackgroundCompat(entry.configuration.background)
        .foregroundStyle(.white)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func leadingStreak() -> Int {
        max(entry.day.prayersStreak, entry.day.athkarStreak, entry.day.quranStreak)
    }

    private func ring(progress: Double, center: Text) -> some View {
        ZStack {
            Circle()
                .stroke(WidgetInk.hairline, lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.02, progress)))
                .stroke(WidgetInk.accent, style: .init(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                center
                Text("%")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 62, height: 62)
    }

    private func taskRow(symbol: String, label: String, done: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(symbol)")
                .font(.caption2)
                .foregroundStyle(done ? WidgetInk.accent : .white.opacity(0.35))
            Text(label)
                .font(.caption2)
                .foregroundStyle(done ? .white : .white.opacity(0.6))
        }
    }
}


struct DailyTasksWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DikhrDailyTasks",
                               intent: DailyTasksConfigIntent.self,
                               provider: DailyTasksProvider()) { entry in
            DailyTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("مهام اليوم")
        .description("متابعة العبادات: تقدّم أذكار اليوم وقراءته والصلوات، مع المداومة. اضغطة مطولة لاختيار الخلفية.")
        .supportedFamilies([.systemSmall])
    }
}

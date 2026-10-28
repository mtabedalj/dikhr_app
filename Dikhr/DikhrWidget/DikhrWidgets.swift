import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Widget bundle
//
// Widget set (the original athkarWidgetExtension's core look, rebuilt):
//   FivePrayersWidget   — flagship prayers card (flagship MyWidgetFivePrayersElement
//                         / MyWidgetNextPrayerInk parity, 3 selectable backgrounds)
//   CounterWidget       — interactive tasbih counter, MyWidgetTicket restyle
//   DailyTasksWidget    — متابعة العبادات progress (MyWidgetTaskProgressElement parity)
//   CounterLiveActivity — the counter Live Activity (unchanged design/model)
//
// Shared data stays on the app-group model (DikhrShared / DikhrStreaksBridge).

// MARK: - Counter widget (interactive, ticket restyle)

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

    private var progress: Double {
        guard entry.target > 0 else { return 0 }
        return Double(min(entry.count, entry.target)) / Double(entry.target)
    }

    var body: some View {
        // MyWidgetTicket look: dark stub card, dhikr name above a dashed
        // perforation (the tear line), big count, and the accent stub footer.
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                Text(entry.name)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                TicketPerforation(color: WidgetInk.hairline)
            }
            Text(WidgetLocaleDigits.apply(String(entry.count)))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Button(intent: IncrementCounterIntent()) {
                Label("عدّ", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .tint(.black.opacity(0.85))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(WidgetInk.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ticketContainerBackground()
        .foregroundStyle(.white)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private extension View {
    @ViewBuilder
    func ticketContainerBackground() -> some View {
        containerBackground(for: .widget) { widgetBackgroundPainter(.dark) }
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
        FivePrayersWidget()
        CounterWidget()
        DailyTasksWidget()
        CounterLiveActivity()
    }
}

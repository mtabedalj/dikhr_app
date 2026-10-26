import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Counter Live Activity (العداد الحيّ)

/// Renders inside the widget extension via ActivityConfiguration:
/// Dynamic Island (compact / expanded / minimal) + lock screen.
/// Dhikr name on top, big count, plus a tap-to-count button (App Intent),
/// mirroring the original's "Refresh Live Activity" counter.
struct CounterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CounterActivityAttributes.self) { context in
            // Lock screen / notification banner
            lockScreenView(context)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.name)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: IncrementCounterIntent()) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color(red: 0, green: 0.559, blue: 0.62)))
                    }
                    .buttonStyle(.plain)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.state.count)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            } compactLeading: {
                Image(systemName: "stopwatch")
                    .foregroundStyle(Color(red: 0, green: 0.559, blue: 0.62))
                    .font(.caption2)
                Text("\(context.state.count)")
                    .font(.caption2.bold())
                    .monospacedDigit()
            } compactTrailing: {
                Button(intent: IncrementCounterIntent()) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color(red: 0, green: 0.559, blue: 0.62))
                }
                .buttonStyle(.plain)
            } minimal: {
                Text("\(context.state.count)")
                    .font(.caption2.bold())
                    .monospacedDigit()
            }
        }
    }

    private func lockScreenView(_ context: ActivityViewContext<CounterActivityAttributes>) -> some View {
        VStack(spacing: 10) {
            Text(context.state.name)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(context.state.count)")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Button(intent: IncrementCounterIntent()) {
                Label("سبّح", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .tint(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(red: 0, green: 0.559, blue: 0.62)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

// MARK: - Counter Live Activity attributes (shared by app + widget targets)

#if canImport(ActivityKit) && os(iOS)
/// Attributes for the tasbih counter Live Activity (العداد الحيّ).
/// The system identifies the activity by this type; content carries count + name.
struct CounterActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var count: Int
        var name: String

        init(count: Int, name: String) {
            self.count = count
            self.name = name
        }
    }

    /// Stable string used in logs / quick identification of the activity kind.
    static let activityName = "DikhrCounter"
}

// MARK: - Start / update / end helpers

/// Small wrapper so the app and the widget extension always talk to the same
/// activity type and follow the same enabled-gating rules.
enum DikhrLiveActivity {

    static var isAuthorized: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts (or replaces) the counter Live Activity.
    static func start(count: Int, name: String) {
        guard isAuthorized else { return }
        // End stale instances first so the island never shows duplicates.
        endAll()
        let state = CounterActivityAttributes.ContentState(count: count, name: name)
        _ = try? Activity<CounterActivityAttributes>.request(
            attributes: CounterActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil))
    }

    /// Updates any running counter activity (no-op when none is running).
    static func update(count: Int, name: String) {
        guard isAuthorized else { return }
        let state = CounterActivityAttributes.ContentState(count: count, name: name)
        Task {
            for activity in Activity<CounterActivityAttributes>.activities {
                await activity.update(using: state)
            }
        }
    }

    /// Ends every running counter activity.
    static func end() {
        endAll()
    }

    private static func endAll() {
        Task {
            for activity in Activity<CounterActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
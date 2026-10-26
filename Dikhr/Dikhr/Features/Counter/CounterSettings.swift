import SwiftUI

// MARK: - Counter delay setting
//
// Extraction evidence (original en.lproj/Localizable.strings):
//   'Counter Delay: %lld seconds' => 'Counter Delay: %lld seconds'
// The original exposes this as a SETTING that introduces a gap between
// automatic counts, so the voice counter doesn't double-increment on a
// rapid repeat of the dhikr phrase. Range here is 0–10 s (0 = off,
// original default).

enum CounterDelayStore {
    static let key = "counterDelaySeconds"
    static let maxSeconds = 10

    static var seconds: Int {
        let v = DikhrShared.defaults.integer(forKey: key)
        return min(max(v, 0), maxSeconds)
    }

    static func set(_ seconds: Int) {
        DikhrShared.defaults.set(min(max(seconds, 0), maxSeconds), forKey: key)
    }
}

/// Settings row for the counter delay, matching the original's
/// "Counter Delay: %lld seconds" as an Arabic-first stepper row
/// (Arabic label written inline per project convention).
struct CounterDelayRow: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var seconds = CounterDelayStore.seconds

    var body: some View {
        Stepper(
            settings.t(String(format: "تأخير العداد: %d ثوانٍ", seconds),
                       String(format: "Counter Delay: %d seconds", seconds)),
            value: Binding(
                get: { seconds },
                set: { newValue in
                    seconds = newValue
                    CounterDelayStore.set(newValue)
                }),
            in: 0...CounterDelayStore.maxSeconds)
            .padding(.vertical, 2)
    }
}
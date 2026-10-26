import Foundation
import SwiftUI
import UserNotifications

// MARK: - Duha notification
//
// Original ground truth (binary string): "PrayerActionResultView — duha
// notification" — the original offers an optional duha notification. The duha
// start instant is ground-truth anchored by TimeMoments.json rule "duha"
// (sunrise + 20 min → dhuhr − 10 min, shipped here as
// Dikhr/Resources/home_timemoments.json and decoded by HomeMomentEngine in
// Home/TimeMomentsCard.swift).
//
// Duha drifts daily with sunrise, so a fixed `repeats: true` calendar trigger
// cannot express it — the next 7 days are armed individually
// (UNCalendarNotificationTrigger, exact dates), then re-armed on every app
// activation via DuhaNotificationController.schedule(). The pattern (per-day
// exact triggers + DikhrMethodLoader/DikhrShared city lookup) mirrors
// Home/MomentsScheduler.swift; identifiers use the prefix "com.dikhr.duha".

@MainActor
final class DuhaNotificationController: ObservableObject {
    static let enabledDefaultsKey = "duhaNotifEnabled"   // default false
    static let idPrefix = "com.dikhr.duha"
    private static let daysAhead = 7

    /// Shared instance — the app-level activation refresh uses
    /// `await DuhaNotificationController.shared.schedule()`.
    static let shared = DuhaNotificationController()

    @Published private(set) var authStatus: UNAuthorizationStatus = .notDetermined

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
    }

    // MARK: Duha time (ground-truth rule "duha": sunrise + 20)

    /// Resolves the duha start instant for one day via HomeMomentEngine's
    /// rule "duha" (falls back to sunrise + 20 min from PrayerTimesEngine if
    /// the rule is missing/disabled).
    static func duhaTime(for day: Date, method: PrayerMethod,
                         lat: Double, lng: Double) -> Date? {
        let times = PrayerTimesEngine.calculate(
            method: method, lat: lat, lng: lng, date: day, timeZone: .current)
        let fallback = times.sunrise.addingTimeInterval(
            TimeInterval(HomeMomentEngine.duhaStartAfterSunriseMinutes * 60))
        if let rule = HomeMomentEngine.rules().first(where: { $0.id == "duha" && $0.enabled }) {
            let anchors = HomeMomentEngine.anchorDates(
                now: day, times: times, method: method, lat: lat, lng: lng)
            let start = HomeMomentEngine.resolveDate(rule.start, dates: anchors)
            if start > Date() { return start }
        }
        return fallback > Date() ? fallback : nil
    }

    // MARK: Scheduling

    /// (Re)arms the next 7 days of duha notifications. Called on every app
    /// activation (DikhrApp scenePhase == .active) so days keep drifting with
    /// the moving sunrise, and on every toggle change.
    func schedule() async {
        await cancel()
        guard isEnabled else { return }
        guard await requestAuthorization() else { return }

        let method = DikhrMethodLoader.method(id: DikhrShared.methodID)
        let city = DikhrShared.city
        let calendar = Calendar(identifier: .gregorian)
        let center = UNUserNotificationCenter.current()
        var scheduledIDs: [String] = []
        let rule = HomeMomentEngine.rules().first(where: { $0.id == "duha" })

        for dayOffset in 0..<Self.daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset,
                                          to: calendar.startOfDay(for: Date())) else { continue }
            guard let fireDate = Self.duhaTime(
                for: day, method: method, lat: city.lat, lng: city.lng),
                  fireDate > Date()
            else { continue }

            let id = "\(Self.idPrefix)-\(Self.dayKey(of: fireDate))"
            let content = UNMutableNotificationContent()
            content.title = DikhrStrings.tr("صلاة الضحى", "Duha Prayer")
            content.body = DikhrStrings.tr("حان وقت الضحى — صلاة الأوابين", "It's time for Duha — the prayer of the devoted")
            content.sound = .default
            if let destination = rule?.destination {
                content.userInfo = ["destination": destination]
            }
            let request = UNNotificationRequest(
                identifier: id, content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: triggerComponents(of: fireDate), repeats: false))
            try? await center.add(request)
            scheduledIDs.append(id)
        }
        UserDefaults.standard.set(scheduledIDs, forKey: "duhaScheduledIDs")
    }

    /// Removes every pending duha notification.
    func cancel() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.idPrefix) }
        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
        UserDefaults.standard.set([String](), forKey: "duhaScheduledIDs")
    }

    /// Requested when the toggle is first enabled; reuses AlarmScheduler's
    /// authorization prompt (same .alert/.sound/.badge options as the alarms
    /// and moments schedulers).
    func requestAuthorization() async -> Bool {
        await AlarmScheduler.requestAuthorization()
    }

    func refreshAuthStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in self.authStatus = settings.authorizationStatus }
        }
    }

    func setEnabled(_ on: Bool) async {
        UserDefaults.standard.set(on, forKey: Self.enabledDefaultsKey)
        objectWillChange.send()
        if on {
            await schedule()
        } else {
            await cancel()
        }
    }

    // MARK: Helpers

    private func triggerComponents(of date: Date) -> DateComponents {
        var c = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
        c.second = 0
        return c
    }

    private static func dayKey(of date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: date)
    }
}

// MARK: - Toggle row (appended into DuhaJourneyView; auth rows mirror
// Features/Settings/AlarmSettingsView.swift).

/// Notification toggle + permission-state row, rendered at the bottom of the
/// duha journey. "تفعيل التنبيه" persists "duhaNotifEnabled"; a denied
/// permission shows the same bell.slash guidance as AlarmSettingsView.
struct DuhaNotificationToggleRow: View {
    @StateObject private var controller = DuhaNotificationController.shared
    @State private var enabled = UserDefaults.standard.bool(forKey: DuhaNotificationController.enabledDefaultsKey)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { enabled },
                set: { on in
                    enabled = on
                    Task {
                        await controller.setEnabled(on)
                        controller.refreshAuthStatus()
                    }
                })) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(dikhrTeal)
                    Text(DikhrStrings.tr("تنبيه صلاة الضحى", "Duha Prayer Notification"))
                        .font(.headline)
                }
            }
            Text(DikhrStrings.tr("تنبيه يوميّ عند دخول وقت الضحى للسبعة أيام القادمة، يُعاد تبويبه تلقائيًا مع تحرّك الشروق كل مرة تفتح فيها التطبيق.",
                                 "Daily alert when the Duha time begins for the next seven days, rescheduled automatically with the moving sunrise each time you open the app."))
                .font(.caption)
                .foregroundStyle(.secondary)

            statusRow
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24)
            .fill(Color(.secondarySystemGroupedBackground)))
        .onAppear {
            controller.refreshAuthStatus()
            enabled = controller.isEnabled
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if enabled {
            switch controller.authStatus {
            case .notDetermined:
                Button(DikhrStrings.tr("تفعيل التنبيهات", "Enable Notifications")) {
                    Task {
                        _ = await controller.requestAuthorization()
                        controller.refreshAuthStatus()
                    }
                }
                .foregroundStyle(dikhrTeal)
            case .denied:
                Label(DikhrStrings.tr("التنبيهات غير مفعلة من إعدادات الجهاز", "Notifications are disabled in system Settings"), systemImage: "bell.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .authorized, .provisional, .ephemeral:
                Label(DikhrStrings.tr("التنبيهات مفعلة", "Notifications enabled"), systemImage: "bell.badge.fill")
                    .font(.footnote)
                    .foregroundStyle(dikhrTeal)
            @unknown default:
                EmptyView()
            }
        }
    }
}
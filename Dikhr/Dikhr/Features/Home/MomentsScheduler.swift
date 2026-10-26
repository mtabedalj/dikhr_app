import Foundation
import UserNotifications
import SwiftUI

// MARK: - TimeMoments local notifications
//
// Original ground truth: the bundle's TimeMoments.json (shipped here as the
// byte-identical Dikhr/Resources/home_timemoments.json, already decoded by
// HomeMomentEngine in Home/TimeMomentsCard.swift) anchors daily/weekly/seasonal
// content windows to prayer-time anchors (fajr/sunrise/dhuhr/asr/maghrib/isha/
// nextFajr/iqama0-4/nightMiddle/lastThird/clockMidnight) with minute offsets,
// weekday lists (`days`, 0=Sun..6=Sat, e.g. salawatEvening runs Thursday
// maghrib → next fajr = ليلة الجمعة), priorities and hijri conditions.
//
// This scheduler turns the rule *start instants* into local notifications for
// the coming week (UNCalendarNotificationTrigger, refreshed on every
// schedule()). Anchor prayer times vary daily, so fixed `repeats: true`
// triggers cannot express "isha + 40 minutes" — days are re-armed ahead, the
// same way AlarmScheduler handles prayer alarms. Multiple rules that begin at
// the same instant (e.g. prayer0 + before0 both start at fajr) collapse into
// one notification: the highest-priority rule wins.
// Anchor math is reused from HomeMomentEngine so notifications, the home card
// and any widget agree on the same windows.

enum MomentsScheduler {
    static let enabledDefaultsKey = "momentsSchedulerEnabled"
    private static let scheduledIDsKey = "momentsScheduledIDs"
    private static let daysAhead = 7
    private static let idPrefix = "moment-"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledDefaultsKey)
    }

    // MARK: One scheduled moment (exposed for previews/tests)

    struct ScheduledMoment: Identifiable, Equatable {
        let rule: HomeMoment
        let fireDate: Date
        var id: String { "\(rule.id)-\(fireDate.timeIntervalSince1970)" }
    }

    /// Computes the moments to notify about for the coming `daysAhead` days.
    /// Public so integration can preview what will be scheduled.
    static func plannedMoments(now: Date = .now) -> [ScheduledMoment] {
        let method = DikhrMethodLoader.method(id: DikhrShared.methodID)
        let city = DikhrShared.city
        let calendar = Calendar(identifier: .gregorian)
        var bestByInstant: [Date: ScheduledMoment] = [:]

        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset,
                                          to: calendar.startOfDay(for: now)) else { continue }
            let times = PrayerTimesEngine.calculate(
                method: method, lat: city.lat, lng: city.lng, date: day, timeZone: .current)
            let anchors = HomeMomentEngine.anchorDates(
                now: day, times: times, method: method,
                lat: city.lat, lng: city.lng)

            for rule in HomeMomentEngine.rules() where rule.enabled {
                let start = HomeMomentEngine.resolveDate(rule.start, dates: anchors)
                var end = HomeMomentEngine.resolveDate(rule.end, dates: anchors)
                if let cap = rule.end.cap {
                    let endDate = HomeMomentEngine.resolveDate(
                        .init(anchor: cap, offset: 0, cap: nil), dates: anchors)
                    end = min(end, endDate)
                }
                guard end > start, start > now else { continue }
                // `days` applies to the weekday of the window's start instant
                // (0=Sunday..6=Saturday), matching HomeMomentEngine.current().
                let weekday = (calendar.component(.weekday, from: start) - 1) % 7
                guard rule.days.contains(weekday) else { continue }
                guard HomeMomentEngine.conditionMet(
                    rule.condition, now: start,
                    adjustment: SettingsStore.shared.hijriAdjustment)
                else { continue }

                let moment = ScheduledMoment(rule: rule, fireDate: start)
                if let existing = bestByInstant[start] {
                    if rule.priority > existing.rule.priority {
                        bestByInstant[start] = moment
                    }
                } else {
                    bestByInstant[start] = moment
                }
            }
        }
        return bestByInstant.values.sorted { $0.fireDate < $1.fireDate }
    }

    // MARK: Scheduling

    /// (Re)schedules moment notifications for the coming week.
    static func schedule() async {
        await cancel()
        guard isEnabled else { return }
        guard await AlarmScheduler.requestAuthorization() else { return }

        let center = UNUserNotificationCenter.current()
        var scheduledIDs: [String] = []
        for moment in plannedMoments() {
            let id = "\(idPrefix)\(moment.rule.id)-\(dayKey(of: moment.fireDate))"
            let content = UNMutableNotificationContent()
            content.title = moment.rule.arabicTitle
            if !moment.rule.arabicDetail.isEmpty {
                content.body = moment.rule.arabicDetail
            }
            content.sound = .default
            content.userInfo = ["destination": moment.rule.destination]

            let request = UNNotificationRequest(
                identifier: id, content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: triggerComponents(of: moment.fireDate), repeats: false))
            Task { try? await center.add(request) }
            scheduledIDs.append(id)
        }
        UserDefaults.standard.set(scheduledIDs, forKey: scheduledIDsKey)
    }

    /// Removes every pending moment notification.
    static func cancel() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
        UserDefaults.standard.set([String](), forKey: scheduledIDsKey)
    }

    static func setEnabled(_ on: Bool) async {
        UserDefaults.standard.set(on, forKey: enabledDefaultsKey)
        if on {
            await schedule()
        } else {
            await cancel()
        }
    }

    /// IDs recorded by the last successful schedule() (diagnostics hook).
    static var lastScheduledIDs: [String] {
        UserDefaults.standard.stringArray(forKey: scheduledIDsKey) ?? []
    }

    // MARK: Helpers

    private static func triggerComponents(of date: Date) -> DateComponents {
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

// MARK: - Settings toggle row (integration request: SettingsView)

/// Toggle row for the settings page — integration wires it next to the other
/// notification rows in Features/Settings/SettingsView.swift.
struct MomentsSchedulerToggleRow: View {
    @EnvironmentObject private var settings: SettingsStore
    @AppStorage(MomentsScheduler.enabledDefaultsKey) private var enabled = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { enabled },
            set: { on in
                enabled = on
                Task { await MomentsScheduler.setEnabled(on) }
            })) {
            VStack(alignment: .leading, spacing: 3) {
                Label(settings.t("تنبيهات الأذكار والأذان", "Athkar & Adhan Alerts"), systemImage: "bell.badge")
                    .font(.headline)
                Text(settings.t("تنبيه عند بدء أوقات الأذكار اليومية والأسبوعية (الصلاة على النبي ﷺ، ساعة الإجابة، الأيام البيض…) وفق جدول الأوقات.",
                                "Notifies when scheduled athkar windows begin (salawat, the hour of answered prayer, white days…)."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
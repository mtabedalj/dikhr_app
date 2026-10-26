import Foundation
import AlarmKit
import ActivityKit
import SwiftUI

/// Real device alarms for the prayer athan via Apple's AlarmKit (iOS 26+),
/// mirroring the original's "منبه الأذان" that rings even when the device is
/// on silent mode ("منبه الأذان يعمل تلقائيًا حتى لو كان الجهاز في وضع الصامت").
/// This is a second path
/// alongside `AlarmScheduler` notifications: notifications keep covering
/// reminders (before-athan, iqama); AlarmKit covers the athan alarms
/// themselves. Both run independently, like the original app.
enum AthanAlarmController {

    static let enabledDefaultsKey = "athanRealAlarmEnabled"
    private static let scheduledIDsKey = "athanAlarmScheduledIDs"
    private static let daysAhead = 7

    static var isEnabled: Bool {
        get { DikhrShared.defaults.bool(forKey: enabledDefaultsKey) }
        set { DikhrShared.defaults.set(newValue, forKey: enabledDefaultsKey) }
    }

    // MARK: - Authorization

    static func authorizationState() -> AlarmManager.AuthorizationState {
        AlarmManager.shared.authorizationState
    }

    /// Prompts the system "Alarms" authorization state; returns true when authorized.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let state = (try? await AlarmManager.shared.requestAuthorization()) ??
            AlarmManager.shared.authorizationState
        return state == .authorized
    }

    // MARK: - Scheduling

    /// Cancels every scheduled athan alarm, then re-schedules the enabled
    /// prayers for today + 6 days (mirrors AlarmScheduler's window). No-ops
    /// (after cleanup) when the feature is off or authorization was denied —
    /// the notification path keeps running regardless.
    static func rescheduleAll(configs: [PrayerAlarmConfig], method: PrayerMethod, city: City) async {
        cancelMine()

        guard isEnabled, !configs.filter(\.enabled).isEmpty else { return }
        guard await requestAuthorization() else { return }

        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        var scheduledIDs: [String] = []

        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))
            else { continue }
            let times = PrayerTimesEngine.calculate(
                method: method, lat: city.lat, lng: city.lng, date: day, timeZone: .current)
            let map: [(String, Date)] = [
                ("fajr", times.fajr), ("sunrise", times.sunrise), ("dhuhr", times.dhuhr),
                ("asr", times.asr), ("maghrib", times.maghrib), ("isha", times.isha)]
            for config in configs where config.enabled {
                guard let (_, prayerDate) = map.first(where: { $0.0 == config.prayer }) else { continue }
                let fire = fireDate(config: config, prayerDate: prayerDate)
                guard fire > now else { continue }
                do {
                    let alarm = try await AlarmManager.shared.schedule(
                        id: UUID(),
                        configuration: configuration(config: config, fire: fire, label: kindLabel(config.prayer)))
                    scheduledIDs.append(alarm.id.uuidString)
                } catch let error as AlarmManager.AlarmError where error == .maximumLimitReached {
                    // AlarmKit caps the number of live alarms; stop adding for
                    // further days, the notification path still covers them.
                    return
                } catch {
                    // Any failure falls back to the notification path silently.
                    continue
                }
            }
        }
        DikhrShared.defaults.set(scheduledIDs, forKey: scheduledIDsKey)
    }

    /// One-off test alarm mirroring the original's "منبه تجريبي (بعد 10 ثوانٍ)".
    static func scheduleTest(fire: Date = Date().addingTimeInterval(10)) async {
        guard await requestAuthorization() else { return }
        _ = try? await AlarmManager.shared.schedule(
            id: UUID(),
            configuration: AlarmManager.AlarmConfiguration<AthanAlarmMeta>(
                schedule: .fixed(fire),
                attributes: AthanAlarmController.attributes(
                    presentation: presentation(title: "منبه تجريبي")),
                sound: alertSound(for: "fajr")))
    }

    static func cancelMine() {
        // Our own stored alarm IDs …
        let stored = DikhrShared.defaults.stringArray(forKey: scheduledIDsKey) ?? []
        for raw in stored {
            if let id = UUID(uuidString: raw) { try? AlarmManager.shared.cancel(id: id) }
        }
        DikhrShared.defaults.removeObject(forKey: scheduledIDsKey)
        // … plus any alarm left over among the app's AlarmKit alarms
        // (AlarmManager.alarms is scoped to this app; Dikhr has no other consumer).
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        for alarm in alarms {
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
    }

    static func scheduledCount() -> Int {
        ((try? AlarmManager.shared.alarms) ?? []).count
    }

    // MARK: - Alarm configuration

    private static func configuration(
        config: PrayerAlarmConfig, fire: Date, label: String
    ) -> AlarmManager.AlarmConfiguration<AthanAlarmMeta> {
        AlarmManager.AlarmConfiguration(
            schedule: .fixed(fire),
            attributes: attributes(presentation: presentation(title: "أذان \(label)")),
            sound: alertSound(for: config.prayer))
    }

    /// `AlarmAttributes` generic `Metadata` can't be inferred from the member
    /// init (metadata is optional with no Metadata-typed parameter), so the
    /// type is spelled out explicitly here.
    private static func attributes(presentation: AlarmPresentation) -> AlarmAttributes<AthanAlarmMeta> {
        AlarmAttributes<AthanAlarmMeta>(presentation: presentation, tintColor: teal)
    }

    private static func presentation(title: String) -> AlarmPresentation {
        AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: resource(title),
                // stopButton is required on the iOS 26.0 init; Apple marks it
                // deprecated starting iOS 26.1 (system stops alarms natively).
                stopButton: AlarmButton(
                    text: resource("إيقاف"),
                    textColor: .white,
                    systemImageName: "stop.fill")))
    }

    /// Verbatim LocalizedStringResource from a runtime Arabic string (the app
    /// uses inline Arabic, so the string renders as-is — no table lookup).
    private static func resource(_ string: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(string))
    }

    /// Per-prayer sound: a catalog full-athan track when the user picked one
    /// (downloaded into Library/Sounds), else bundled athan .caf / imported
    /// sounds staged into Library/Sounds. AlarmKit has no explicit "silent"
    /// alarm sound, so the "بلا صوت" option falls back to the system default.
    ///
    /// AlarmKit file-location constraint (documented from Apple's surfaces):
    /// - `AlertConfiguration.AlertSound.named(_:)` resolves the audio from the
    ///   app bundle OR the container's `Library/Sounds` directory (WWDC25
    ///   session 230); downloaded full athans therefore must sit in
    ///   Library/Sounds, like the original does after "تُنزَّل أولًا" ("The
    ///   athan needs to be downloaded first" → otherwise fall back to .default).
    /// - The name passed to `.named` must INCLUDE the file extension: verified
    ///   on iOS 26.5 (Apple Dev Forums thread 836432), `.named("sound.caf")`
    ///   plays while a bare base name silently falls back to the system sound.
    /// - Unlike UNNotificationSound (30 s cap, caf/aiff/wav only), the AlarmKit
    ///   alarm is what makes the FULL athan possible ("يمكن أن يتضمن الأذان
    ///   كاملًا") — multi-minute audio is intended here.
    private static func alertSound(for prayer: String) -> AlertConfiguration.AlertSound {
        // Catalog full-athan alarm track takes precedence when it's on disk.
        if let track = AthanTrackStore.selectedTrack(for: prayer),
           let name = AthanTrackStore.alarmSoundName(for: track) {
            // The catalog downloads keep their extension in Library/Sounds:
            // pass "athan-maka.m4a", not the bare base name.
            return .named(name)
        }
        switch AthanSoundStore.selected(for: prayer) {
        case .defaultSystem, .silent:
            return .default
        case .bundled(let file):
            return .named((file as NSString).deletingPathExtension)
        case .imported(let file):
            // Sounds staged for notifications live in Library/Sounds; keep them
            // staged, then point AlarmKit at the same name.
            _ = AthanSoundStore.stageForNotifications(AthanSoundStore.selected(for: prayer))
            return .named((file as NSString).deletingPathExtension)
        }
    }

    private static var teal: Color {
        Color(red: 1.0 / 255.0, green: 143.0 / 255.0, blue: 158.0 / 255.0)
    }

    private static func fireDate(config: PrayerAlarmConfig, prayerDate: Date) -> Date {
        switch config.mode {
        case .atAthan: return prayerDate
        case .before: return prayerDate.addingTimeInterval(-Double(config.offsetMinutes) * 60)
        case .after: return prayerDate.addingTimeInterval(Double(config.offsetMinutes) * 60)
        }
    }

    private static func kindLabel(_ prayer: String) -> String {
        switch prayer {
        case "fajr": return "الفجر"
        case "sunrise": return "الشروق"
        case "dhuhr": return "الظهر"
        case "asr": return "العصر"
        case "maghrib": return "المغرب"
        case "isha": return "العشاء"
        default: return prayer
        }
    }
}

/// Empty metadata for our alarms — presentational only.
struct AthanAlarmMeta: AlarmMetadata {}
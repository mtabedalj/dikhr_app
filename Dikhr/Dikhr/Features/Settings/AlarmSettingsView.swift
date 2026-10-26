import SwiftUI
import UserNotifications

struct AlarmSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var configs: [PrayerAlarmConfig] = AlarmScheduler.loadConfigs()
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var scheduled = false
    @State private var showSoundPage = false

    var body: some View {
        Form {
            // AlarmKit path: real device alarm ("منبه الأذان") ringing through
            // silent mode, plus a always-visible default-prayer athan sound row.
            Section {
                AthanAlarmToggleRow()
                NavigationLink {
                    AthanSoundPickerView(prayer: "fajr", prayerTitle: settings.t("الفجر", "Fajr"))
                } label: {
                    Label(settings.t("صوت الأذان", "Adhan Sound"), systemImage: "music.note.list")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }
            }

            Section {
                switch authStatus {
                case .notDetermined:
                    Button(settings.t("تفعيل التنبيهات", "Enable Notifications")) {
                        Task {
                            let granted = await AlarmScheduler.requestAuthorization()
                            refreshStatus()
                            if granted { await apply() }
                        }
                    }
                case .denied:
                    Label(settings.t("التنبيهات غير مفعلة من إعدادات الجهاز", "Notifications are disabled in system Settings"), systemImage: "bell.slash")
                        .foregroundStyle(.secondary)
                case .authorized, .provisional, .ephemeral:
                    Label(settings.t("التنبيهات مفعلة", "Notifications enabled"), systemImage: "bell.badge.fill")
                        .foregroundStyle(Color.accentColor)
                @unknown default:
                    EmptyView()
                }
            } footer: {
                Text(settings.t("يُعاد تبويب الأذان تلقائيًا كل مرة تفتح فيها التطبيق.", "Adhan times are rescheduled automatically each time you open the app."))
            }

            Section(settings.t("الأذان والتذكير", "Adhan & Reminders")) {
                ForEach($configs) { $config in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(prayerName(config.prayer), isOn: $config.enabled)
                            .onChange(of: config.enabled) { _, _ in
                                Task { await apply() }
                            }
                        if config.enabled && config.prayer != "sunrise" {
                            Picker(settings.t("الوقت", "Time"), selection: $config.mode) {
                                ForEach(PrayerAlarmConfig.Mode.allCases) { mode in
                                    Text(modeLabel(mode)).tag(mode)
                                }
                            }
                            .onChange(of: config.mode) { _, _ in Task { await apply() } }
                            if config.mode != .atAthan {
                                Stepper("\(settings.t("الفارق", "Offset")): \(config.offsetMinutes) \(settings.t("دقيقة", "min"))",
                                        value: $config.offsetMinutes, in: 1...60, step: 5)
                                    .onChange(of: config.offsetMinutes) { _, _ in Task { await apply() } }
                            }
                            NavigationLink(settings.t("الصوت", "Sound")) {
                                AthanSoundPickerView(
                                    prayer: config.prayer,
                                    prayerTitle: prayerTitle(config.prayer))
                            }
                            Toggle(settings.t("تذكير الإقامة", "Iqama Reminder"), isOn: $config.iqamaEnabled)
                                .onChange(of: config.iqamaEnabled) { _, _ in Task { await apply() } }
                            if config.iqamaEnabled {
                                Stepper("\(settings.t("بعد الأذان بـ", "After adhan, ")): \(config.iqamaMinutes) \(settings.t("دقيقة", "min"))",
                                        value: $config.iqamaMinutes, in: 5...30, step: 5)
                                    .onChange(of: config.iqamaMinutes) { _, _ in Task { await apply() } }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(settings.t("منبه الصلاة", "Prayer Alarm"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSoundPage) {
            AthanSoundPickerView(
                prayer: ProcessInfo.processInfo.environment["DIKHR_SOUND_PAGE_PRAYER"] ?? "fajr",
                prayerTitle: prayerTitle("fajr"))
        }
        .onAppear {
            refreshStatus()
            if ProcessInfo.processInfo.environment["DIKHR_SOUND_PAGE"] != nil {
                showSoundPage = true
            }
        }
    }

    private func prayerName(_ prayer: String) -> String {
        switch prayer {
        case "fajr": return settings.t("منبه الفجر", "Fajr Alarm")
        case "sunrise": return settings.t("تنبيه الشروق", "Sunrise Alert")
        case "dhuhr": return settings.t("منبه الظهر", "Dhuhr Alarm")
        case "asr": return settings.t("منبه العصر", "Asr Alarm")
        case "maghrib": return settings.t("منبه المغرب", "Maghrib Alarm")
        case "isha": return settings.t("منبه العشاء", "Isha Alarm")
        default: return prayer
        }
    }

    /// Bare prayer title (no alarm prefix), for the sound picker header.
    private func prayerTitle(_ prayer: String) -> String {
        switch prayer {
        case "fajr": return settings.t("الفجر", "Fajr")
        case "sunrise": return settings.t("الشروق", "Sunrise")
        case "dhuhr": return settings.t("الظهر", "Dhuhr")
        case "asr": return settings.t("العصر", "Asr")
        case "maghrib": return settings.t("المغرب", "Maghrib")
        case "isha": return settings.t("العشاء", "Isha")
        default: return prayer
        }
    }

    /// English labels for the adhan-time modes (mode.arabic stays Arabic).
    private func modeLabel(_ mode: PrayerAlarmConfig.Mode) -> String {
        switch mode {
        case .atAthan: return settings.t(mode.arabic, "At adhan")
        case .before: return settings.t(mode.arabic, "Minutes before")
        case .after: return settings.t(mode.arabic, "Minutes after")
        }
    }

    private func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            Task { @MainActor in authStatus = s.authorizationStatus }
        }
    }

    private func apply() async {
        AlarmScheduler.save(configs)
        let method = SettingsStore.loadMethods().first(where: { $0.id == settings.methodID }) ?? PrayerMethod(
            fajrAngle: 18.5, ishaAngle: 0, ishaInterval: 90, name: "", params: "ummAlQura")
        // Notifications keep the reminder path (before-athan, iqama) as before.
        await AlarmScheduler.rescheduleAll(
            configs: configs,
            method: method,
            city: settings.currentCity)
        // AlarmKit adds the silent-mode-proof device alarm path, kept
        // alongside the notifications — the original uses both.
        await AthanAlarmController.rescheduleAll(
            configs: configs,
            method: method,
            city: settings.currentCity)
        scheduled = true
    }
}
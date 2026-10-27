import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var showAlarms = false
    @State private var showTheme = false

    var body: some View {
        NavigationStack {
            SettingsSectionsView(sheetTopCards: false)
                .navigationTitle(settings.t("الإعدادات", "Settings"))
                .onAppear {
                    if ProcessInfo.processInfo.environment["DIKHR_ALARM_PAGE"] != nil {
                        showAlarms = true
                    }
                    if ProcessInfo.processInfo.environment["DIKHR_THEME_PAGE"] != nil {
                        showTheme = true
                    }
                }
                .navigationDestination(isPresented: $showAlarms) {
                    AlarmSettingsView()
                }
                .navigationDestination(isPresented: $showTheme) {
                    ThemeSettingsView()
                }
        }
    }
}

/// The settings Form body, shared by the settings tab (SettingsView) and the
/// settings bottom sheet (SettingsSheetView). `sheetTopCards` prepends the
/// original sheet's special cards (التطبيق / ويدجت على ذوقك / النسخة الحصرية).
struct SettingsSectionsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var methods = SettingsStore.loadMethods()
    var sheetTopCards = false

    var body: some View {
        Form {
            if sheetTopCards {
                DikhrSettingsTopCards()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section(settings.t("الموقع", "Location")) {
                NavigationLink("\(settings.t("المدينة", "City")): \(settings.city.name)") {
                    CityPickerView()
                }
            }
            Section(settings.t("مواقيت الصلاة", "Prayer Times")) {
                NavigationLink(settings.t("منبه الصلاة", "Prayer Alarm")) {
                    AlarmSettingsView()
                }
                Picker(settings.t("طريقة الحساب", "Calculation Method"), selection: $settings.methodID) {
                    ForEach(methods) { method in
                        Text(method.name).tag(method.id)
                    }
                }
            }
            Section(settings.t("تنبيهات الأذكار والأذان", "Athkar & Adhan Alerts")) {
                MomentsSchedulerToggleRow()
            }
            Section(settings.t("اللغة", "Language")) {
                Picker(settings.t("لغة الواجهة", "App Language"), selection: $settings.lang) {
                    Text("العربية").tag(SettingsStore.Language.arabic)
                    Text("English").tag(SettingsStore.Language.english)
                }
                .pickerStyle(.segmented)
            }
            Section(settings.t("المظهر", "Appearance")) {
                NavigationLink(settings.t("الثيم والأيقونة", "Theme & Icon")) {
                    ThemeSettingsView()
                }
                Toggle(settings.t("تكبير الخط", "Larger Text"), isOn: $settings.fontSizeBoost)
                Toggle(settings.t("إظهار الترجمة", "Show Translation"), isOn: $settings.showTranslation)
            }
            Section(settings.t("العداد", "Counter")) {
                CounterDelayRow()
            }
            Section(settings.t("عُفص الصلاة", "Prayer Focus")) {
                PrayerFocusSettingsRow()
            }
            Section(settings.t("الاشتراك والبيانات", "Subscription & Data")) {
                SettingsProRow()
                NavigationLink(settings.t("نسخ احتياطي", "Backup")) {
                    BackupView()
                }
            }
            Section(settings.t("معلومات", "About")) {
                NavigationLink(settings.t("الأسئلة الشائعة", "FAQ")) { FaqView() }
                NavigationLink(settings.t("اختبار", "Quiz")) { QuizView() }
                NavigationLink(settings.t("الشخصيات الإسلامية", "Islamic Figures")) { EventsView() }
                NavigationLink(settings.t("الأخبار", "News")) { NewsView() }
            }
            Section(settings.t("التقويم", "Calendar")) {
                Stepper("\(settings.t("تعديل التاريخ الهجري", "Hijri Date Offset")): \(settings.hijriAdjustment)",
                        value: $settings.hijriAdjustment, in: -3...3)
            }
            Section {
                Label(settings.t("أذكار ١.٠ — معاينة", "Athkar 1.0 — Preview"), systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CityPickerView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var query = ""

    private var sections: [(String, String, [City])] {
        let all = SettingsStore.loadCities()
        guard !query.isEmpty else { return all }
        return all.compactMap { code, country, cities in
            let filtered = cities.filter {
                $0.name.contains(query) || ($0.tag?.localizedCaseInsensitiveContains(query) ?? false)
            }
            return filtered.isEmpty ? nil : (code, country, filtered)
        }
    }

    var body: some View {
        List {
            ForEach(sections, id: \.0) { _, country, cities in
                Section(country) {
                    ForEach(cities) { city in
                        Button {
                            settings.city = city
                            settings.useAutoLocation = false
                        } label: {
                            HStack {
                                Text(city.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if settings.city.id == city.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: settings.t("ابحث عن مدينة", "Search for a city"))
        .navigationTitle(settings.t("اختر المدينة", "Choose City"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
import SwiftUI

/// Plan creation form (the original's plan flow): plan name, custom daily
/// reading amount, start-from-beginning vs start-from-specific-wird, and
/// when-to-start (اليوم / غدًا / بعد غد).
struct KhatmahPlanView: View {
    @EnvironmentObject private var settings: SettingsStore
    var onCreated: (KhatmahPlan) -> Void

    @State private var name = ""
    @State private var amount = 1
    @State private var isCustomAmount = false
    @State private var startMode: StartMode = .beginning
    @State private var specificDay = 1
    @State private var whenToStart: WhenToStart = .today
    @Environment(\.dismiss) private var dismiss

    enum StartMode: Hashable { case beginning, specificWird }
    enum WhenToStart: Int, CaseIterable, Hashable {
        case today = 0, tomorrow = 1, dayAfter = 2

        var label: String {
            switch self {
            case .today: return "اليوم"
            case .tomorrow: return "غدًا"
            case .dayAfter: return "بعد غد"
            }
        }

        var englishLabel: String {
            switch self {
            case .today: return "Today"
            case .tomorrow: return "Tomorrow"
            case .dayAfter: return "Day after"
            }
        }

        var localizedLabel: String {
            DikhrStrings.tr(label, englishLabel)
        }
    }

    /// Preset daily amounts with the duration-unit picker behavior for 3–10+
    /// (days 3…10 presets, plus bigger custom amounts).
    private let presetAmounts = [1, 2, 3, 4, 5, 10, 20]
    private let maxPortions = 604

    private var previewStartPage: Int {
        guard startMode == .specificWird else { return 1 }
        return min((specificDay - 1) * max(amount, 1) + 1, KhatmahStore.totalPages)
    }

    /// Wirds the picker shows for a full-from-beginning mushaf at this amount.
    private var pickerMax: Int {
        Int(ceil(Double(KhatmahStore.totalPages) / Double(max(amount, 1))))
    }

    private var estimatedDays: Int {
        let preview = KhatmahPlan(
            name: name, startDate: Date(), pagesPerDay: max(amount, 1), startPage: previewStartPage)
        return KhatmahStore.daysTotal(for: preview)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(settings.t("اسم الخطة", "Plan Name")) {
                    TextField(settings.t("ختمة القرآن", "Quran Khatmah"), text: $name)
                }

                Section {
                    amountSection
                    Text(settings.t("المدة التقديرية: \(estimatedDays) يوم",
                                    "Estimated duration: \(estimatedDays) days"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(settings.t("الورد اليومي", "Daily Portion"))
                }

                Section {
                    Picker(settings.t("البداية", "Start Point"), selection: $startMode) {
                        Text(settings.t("من البداية", "From the Beginning")).tag(StartMode.beginning)
                        Text(settings.t("من ورد محدد", "From a Specific Wird")).tag(StartMode.specificWird)
                    }
                    .pickerStyle(.segmented)
                    if startMode == .specificWird {
                        Picker(settings.t("الورد المحدد", "Specific Wird"), selection: $specificDay) {
                            ForEach(1...pickerMax, id: \.self) { day in
                                Text("\(specificWirdLabel(day))").tag(day)
                            }
                        }
                        .frame(height: 160)
                    }
                } header: {
                    Text(settings.t("نقطة البدء", "Start Point"))
                }

                Section(settings.t("موعد البدء", "Start Date")) {
                    Picker(settings.t("تبدأ الخطة", "Plan Starts"), selection: $whenToStart) {
                        ForEach(WhenToStart.allCases, id: \.self) { option in
                            Text(option.localizedLabel).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    createPlan()
                } label: {
                    Text(settings.t("بدء الخطة", "Start Plan"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.accentColor)
                .foregroundStyle(.white)
            }
            .navigationTitle(settings.t("خطة ختمة جديدة", "New Khatmah Plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("إلغاء", "Cancel")) { dismiss() }
                }
            }
            .onChange(of: amount) { _ in clampSpecificDay() }
            .onChange(of: startMode) { _ in clampSpecificDay() }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isCustomAmount {
                Stepper(settings.t("مخصص: \(amount) صفحة/يوم", "Custom: \(amount) pages/day"), onIncrement: {
                    amount = min(amount + 1, maxPortions)
                }, onDecrement: {
                    amount = max(amount - 1, 1)
                })
            } else {
                Picker(settings.t("نسبة القراءة اليومية", "Daily Reading Amount"), selection: $amount) {
                    ForEach(presetAmounts, id: \.self) { a in
                        Text(settings.t("\(a) صفحة/يوم", "\(a) pages/day")).tag(a)
                    }
                }
                .pickerStyle(.segmented)
            }
            Toggle(settings.t("مخصص", "Custom"), isOn: $isCustomAmount)
        }
    }

    private func specificWirdLabel(_ day: Int) -> String {
        var startPage = (day - 1) * max(amount, 1) + 1
        if startPage > KhatmahStore.totalPages { startPage = KhatmahStore.totalPages }
        let label = KhatmahStore.pageInfo(page: startPage)?.surahName ?? ""
        return settings.t("الورد \(day) — \(label)", "Wird \(day) — \(label)")
    }

    private func clampSpecificDay() {
        if specificDay > pickerMax { specificDay = pickerMax }
    }

    private func createPlan() {
        let startPage = previewStartPage
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let beginsOn = cal.date(byAdding: .day, value: whenToStart.rawValue, to: base) ?? base
        let plan = KhatmahStore.createPlan(
            name: name, pagesPerDay: amount, startPage: startPage, beginsOn: beginsOn)
        onCreated(plan)
        dismiss()
    }
}
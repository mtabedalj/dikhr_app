import SwiftUI

/// Khatmah feature entry: when a plan is active this is the plan dashboard
/// (progress ring, day counter, today's portion card with undo, history);
/// with no active plan it is the setup CTA.
struct KhatmahView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var plan: KhatmahPlan?
    @State private var completed: Set<Int> = []
    @State private var history: [KhatmahCompleted] = []
    @State private var showingPlanForm = false
    @State private var showingCompletionDuaa = false
    @State private var duaText: String?
    @State private var notifOn = false
    @State private var notifMinutes = 8 * 60

    var body: some View {
        Group {
            if let plan {
                dashboard(plan)
            } else {
                emptyState
            }
        }
        .navigationTitle(settings.t("الختمة", "Khatmah"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingPlanForm = true
                } label: {
                    Label(settings.t("خطة جديدة", "New Plan"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingPlanForm) {
            KhatmahPlanView { _ in refresh() }
                .environment(\.layoutDirection, rtlDirection)
        }
        .environment(\.layoutDirection, settings.lang == .arabic ? .rightToLeft : .leftToRight)
        .sheet(isPresented: $showingCompletionDuaa) {
            KhatmahCompletionSheet(text: duaText ?? "")
        }
        .onAppear { refresh() }
    }

    private var rtlDirection: LayoutDirection {
        .rightToLeft
    }

    private func refresh() {
        plan = KhatmahStore.activePlan()
        history = KhatmahStore.history()
        if let plan { completed = KhatmahStore.completedIndices(for: plan) }
        let ud = UserDefaults.standard
        notifOn = ud.bool(forKey: KhatmahStore.notifEnabledKey)
        notifMinutes = ud.object(forKey: KhatmahStore.notifTimeKey) as? Int ?? 8 * 60
        if KhatmahStore.pendingCompletionDuaa() {
            duaText = KhatmahStore.completionDuaa()
            showingCompletionDuaa = true
            KhatmahStore.markCompletionDuaaShown()
        }
    }

    // MARK: - Empty state (no active plan)

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 40)
                Image(systemName: "book.closed")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor)
                Text(settings.t("ابدأ ختمة القرآن", "Complete the Quran"))
                    .font(.title2.bold())
                Text(settings.t("خطط لقراءة القرآن يوميًا بورد محدد، وتتبع تقدمك حتى إتمام الختمة.",
                                "Plan a daily Quran portion and track your progress until you finish the khatmah."))
                    .font(.athkarBody)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button {
                    showingPlanForm = true
                } label: {
                    Text(settings.t("إنشاء خطة", "Create Plan"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                }
                .buttonStyle(.plain)
                if !history.isEmpty {
                    historySection
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Dashboard

    private func dashboard(_ plan: KhatmahPlan) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                dashboardHeader(plan)
                todayCard(plan)
                progressStrip(plan)
                notificationCard(plan)
                historySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func dashboardHeader(_ plan: KhatmahPlan) -> some View {
        let total = KhatmahStore.daysTotal(for: plan)
        let fraction = total == 0 ? 0 : Double(completed.count) / Double(total)
        let todayIndex = KhatmahStore.todayIndex(for: plan)

        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(completed.count)")
                        .font(.title2.bold())
                        .foregroundStyle(Color.accentColor)
                    Text("/\(total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 6) {
                Text(plan.name)
                    .font(.headline)
                Text(settings.t("ورد يومي: \(plan.pagesPerDay) صفحة",
                                "Daily portion: \(plan.pagesPerDay) pages"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if todayIndex >= 0 {
                    Text(settings.t("اليوم \(todayIndex + 1) من \(total)",
                                    "Day \(todayIndex + 1) of \(total)"))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                } else if plan.startDate > Date() {
                    Text(settings.t("لم تبدأ بعد", "Not started yet"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(settings.t("تبدأ من صفحة \(plan.startPage)", "Starts at page \(plan.startPage)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
        .environment(\.layoutDirection, rtlDirection)
    }

    @ViewBuilder
    private func todayCard(_ plan: KhatmahPlan) -> some View {
        let todayIndex = KhatmahStore.todayIndex(for: plan)
        if todayIndex >= 0, let portion = KhatmahStore.portion(for: plan, dayIndex: todayIndex) {
            let isDone = completed.contains(portion.index)
            KhatmahTimerView(portion: portion, isDone: isDone) {
                if isDone {
                    KhatmahStore.undoPortion(plan: plan, index: portion.index)
                } else {
                    KhatmahStore.completePortion(plan: plan, index: portion.index)
                }
                completed = KhatmahStore.completedIndices(for: plan)
                if isDone { return }
                // when the last portion is done the dua appears and the
                // plan moves to history
                if !KhatmahStore.pendingCompletionDuaa() { return }
                duaText = KhatmahStore.completionDuaa()
                showingCompletionDuaa = true
                KhatmahStore.markCompletionDuaaShown()
                self.plan = KhatmahStore.activePlan() // now nil
                history = KhatmahStore.history()
            }
            .environment(\.layoutDirection, rtlDirection)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                Text(plan.startDate > Date() ? settings.t("تبدأ الخطة في موعدها", "The plan starts on schedule")
                                             : settings.t("اكتملت الخطة", "Plan completed"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
        }
    }

    private func progressStrip(_ plan: KhatmahPlan) -> some View {
        let total = KhatmahStore.daysTotal(for: plan)
        return VStack(alignment: .leading, spacing: 10) {
            Text(settings.t("خطة القراءة", "Reading Plan"))
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(0..<total, id: \.self) { index in
                    let done = completed.contains(index)
                    let isToday = KhatmahStore.todayIndex(for: plan) == index
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(done ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1.5)
                                .fill(done ? Color.accentColor.opacity(0.15) : .clear)
                            Image(systemName: done ? "checkmark" : "\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(done ? Color.accentColor : .secondary)
                        }
                        .frame(width: 28, height: 28)
                        if isToday {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
        .environment(\.layoutDirection, rtlDirection)
    }

    // MARK: - Daily reminder notification (settable time)

    private func notificationCard(_ plan: KhatmahPlan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .foregroundStyle(Color.accentColor)
            Toggle(settings.t("تنبيه يومي للورد", "Daily portion reminder"), isOn: Binding(
                get: { notifOn },
                set: { on in
                    KhatmahStore.setNotificationEnabled(on, minutes: notifMinutes)
                    notifOn = on
                }))
                .font(.subheadline)
            if notifOn {
                DatePicker("", selection: Binding(
                    get: {
                        var comps = DateComponents()
                        comps.hour = notifMinutes / 60
                        comps.minute = notifMinutes % 60
                        return Calendar.current.date(from: comps) ?? Date()
                    },
                    set: { newValue in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        notifMinutes = (comps.hour ?? 8) * 60 + (comps.minute ?? 0)
                        KhatmahStore.setNotificationEnabled(true, minutes: notifMinutes)
                        if let i = KhatmahStore.plans().firstIndex(where: { $0.id == plan.id }) {
                            self.plan = KhatmahStore.plans()[i]
                        }
                    }),
                    displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
        .environment(\.layoutDirection, rtlDirection)
    }

    // MARK: - History ("completed khatmahs kept in history")

    @ViewBuilder
    private var historySection: some View {
        if !history.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(settings.t("الختمات المكتملة", "Completed Khatmahs"))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(history) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(QuranPalette.darkGreen)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.subheadline.bold())
                            Text(settings.t("\(item.daysTotal) يوم · \(item.pagesPerDay) صفحة/يوم",
                                            "\(item.daysTotal) days · \(item.pagesPerDay) pages/day"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(KhatmahStore.dateKey(item.completedAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
                }
                Text(settings.t("ستبقى ختمتك المكتملة في السجل عند بدء خطة جديدة.",
                                "Your completed khatmah stays in the history when you start a new plan."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .environment(\.layoutDirection, rtlDirection)
        }
    }
}

/// Sheet shown when a khatmah completes: the khatmah dua text.
private struct KhatmahCompletionSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(QuranPalette.darkGreen)
            Text(settings.t("تمت الختمة بحمد الله", "Khatmah Complete, Praise be to Allah"))
                .font(.title2.bold())
            ScrollView {
                Text(text)
                    .font(.athkarBody)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            Button {
                dismiss()
            } label: {
                Text(settings.t("الإغلاق", "Close"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
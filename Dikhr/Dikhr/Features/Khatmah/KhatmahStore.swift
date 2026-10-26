import Foundation
import SQLite3
import UserNotifications

/// Plan-based Quran khatmah (matching the original Athkar design):
/// a plan divides the Mushaf (604 pages) into daily portions (ورد),
/// starting from page 1 or from a specific wird, with a custom daily
/// reading amount (pages/day) chosen in the setup form.
struct KhatmahPlan: Codable, Identifiable, Hashable {
    /// Page-based portions: the Mushaf is divided by page, first page per wird.
    var id: String = UUID().uuidString
    var name: String
    var startDate: Date
    /// Daily reading amount (pages per day, custom).
    var pagesPerDay: Int
    /// Mushaf page the plan starts from (1…604 = start from beginning).
    var startPage: Int = 1
    var active: Bool = true
    var notificationEnabled: Bool = false
    /// Reminder time as minutes-from-midnight (matches khatmahNotifTime).
    var notificationMinutes: Int = 8 * 60
}

/// One daily portion (ورد) resolved from the Quran pages table.
struct KhatmahPortion: Identifiable, Hashable {
    var id: Int { index }
    let index: Int
    let dayNumber: Int
    let pages: [Int]
    let firstSurah: String
    let firstAyah: Int
    let firstPage: Int
    let firstJuz: Int
}

/// A khatmah kept in history after completion (completedKhatmahs.v1).
struct KhatmahCompleted: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var pagesPerDay: Int
    var daysTotal: Int
    var completedAt: Date
}

/// Persistence + Quran-page reading engine for the khatmah feature.
/// Opens its own read-only sqlite connection to Resources/Quran.sqlite
/// (the `pages` table: id → surah_id, ayah_number, juz_id, surah_name).
enum KhatmahStore {
    static let plansKey = "khatmahPlans.v1"
    static let progressKey = "khatmahProgress.v1"
    static let historyKey = "completedKhatmahs.v1"
    static let duaaShownKey = "khatmahDuaaShown"
    static let notifEnabledKey = "khatmahNotifEnabled"
    static let notifTimeKey = "khatmahNotifTime"
    static let notifIdentifier = "com.athkarApp.Alerts.Khatmah"
    static let totalPages = 604

    // MARK: - Quran pages reader (own sqlite connection, read-only)

    private static var db: OpaquePointer?
    private static let dbQueue = DispatchQueue(label: "dev.dikhr.khatmah.sqlite")

    private static func openDB() -> OpaquePointer? {
        if db != nil { return db }
        dbQueue.sync {
            guard db == nil,
                  let url = Bundle.main.url(forResource: "Quran", withExtension: "sqlite")
            else { return }
            var ptr: OpaquePointer?
            let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
            if sqlite3_open_v2(url.path, &ptr, flags, nil) == SQLITE_OK { db = ptr }
        }
        return db
    }

    struct PageInfo: Hashable {
        let surahID: Int
        let surahName: String
        let ayahNumber: Int
        let juzID: Int
    }

    /// Page 1–604 → (surah, ayah, juz) from the Quran `pages` table.
    static func pageInfo(page: Int) -> PageInfo? {
        guard page >= 1, page <= totalPages, let open = openDB() else { return nil }
        return dbQueue.sync {
            var stmt: OpaquePointer?
            let sql = "SELECT surah_id, ayah_number, juz_id, surah_name FROM pages WHERE id = ?"
            guard sqlite3_prepare_v2(open, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, Int64(page))
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            return PageInfo(
                surahID: Int(sqlite3_column_int64(stmt, 0)),
                surahName: String(cString: sqlite3_column_text(stmt, 3)),
                ayahNumber: Int(sqlite3_column_int64(stmt, 1)),
                juzID: Int(sqlite3_column_int64(stmt, 2)))
        }
    }

    // MARK: - Portion math (computed from the Quran pages)

    /// Number of day-portions the plan needs.
    static func daysTotal(for plan: KhatmahPlan) -> Int {
        let remaining = totalPages - (plan.startPage - 1)
        return max(1, Int(ceil(Double(remaining) / Double(max(plan.pagesPerDay, 1)))))
    }

    /// The portion for a given day index (0-based, from the plan start date).
    static func portion(for plan: KhatmahPlan, dayIndex: Int) -> KhatmahPortion? {
        let total = daysTotal(for: plan)
        guard dayIndex >= 0, dayIndex < total else { return nil }
        let firstPage = plan.startPage + dayIndex * plan.pagesPerDay
        let lastPage = min(firstPage + plan.pagesPerDay - 1, totalPages)
        let pages = Array(firstPage...lastPage)
        let info = pageInfo(page: firstPage) ?? PageInfo(surahID: 1, surahName: "", ayahNumber: 1, juzID: 1)
        return KhatmahPortion(
            index: dayIndex,
            dayNumber: dayIndex + 1,
            pages: pages,
            firstSurah: info.surahName,
            firstAyah: info.ayahNumber,
            firstPage: firstPage,
            firstJuz: info.juzID)
    }

    /// portions list (used by the plan form for the specific-wird picker).
    static func portions(for plan: KhatmahPlan) -> [KhatmahPortion] {
        (0..<daysTotal(for: plan)).compactMap { portion(for: plan, dayIndex: $0) }
    }

    /// Index of the portion that belongs to today (-1 when not started yet).
    static func todayIndex(for plan: KhatmahPlan, on date: Date = Date()) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: plan.startDate)
        let today = cal.startOfDay(for: date)
        let offset = cal.dateComponents([.day], from: start, to: today).day ?? 0
        return (offset >= 0 && offset < daysTotal(for: plan)) ? offset : -1
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func dateKey(_ date: Date = Date()) -> String { dayFormatter.string(from: date) }

    // MARK: - Plans persistence (khatmahPlans.v1)

    static func plans() -> [KhatmahPlan] {
        guard let data = UserDefaults.standard.data(forKey: plansKey),
              let list = try? JSONDecoder().decode([KhatmahPlan].self, from: data)
        else { return [] }
        return list
    }

    private static func savePlans(_ list: [KhatmahPlan]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: plansKey)
        }
    }

    static func activePlan() -> KhatmahPlan? {
        plans().first(where: { $0.active })
    }

    /// Creates a plan; a previously-active plan is deactivated (its finished
    /// or in-progress state is kept, and finished plans remain in history).
    static func createPlan(name: String, pagesPerDay: Int, startPage: Int, beginsOn: Date) -> KhatmahPlan {
        var list = plans()
        for i in list.indices { list[i].active = false }
        let plan = KhatmahPlan(
            name: name.isEmpty ? DikhrStrings.tr("الختمة", "Khatmah") : name,
            startDate: Calendar.current.startOfDay(for: beginsOn),
            pagesPerDay: max(1, min(pagesPerDay, totalPages)),
            startPage: max(1, min(startPage, totalPages)))
        list.insert(plan, at: 0)
        savePlans(list)
        refreshNotification()
        return plan
    }

    /// Deactivates the active plan without history (used by a delete action).
    static func cancelActivePlan() {
        var list = plans()
        for i in list.indices { list[i].active = false }
        savePlans(list)
        refreshNotification()
    }

    /// Updates plan-baked reminder defaults and the global notif keys.
    static func updateNotificationSettings(enabled: Bool, minutes: Int, plan: KhatmahPlan) {
        var list = plans()
        if let i = list.firstIndex(where: { $0.id == plan.id }) {
            list[i].notificationEnabled = enabled
            list[i].notificationMinutes = minutes
        }
        savePlans(list)
        UserDefaults.standard.set(enabled, forKey: notifEnabledKey)
        UserDefaults.standard.set(minutes, forKey: notifTimeKey)
        refreshNotification()
    }

    // MARK: - Progress persistence (khatmahProgress.v1)
    // planID → portionIndex("1") → completion dateKey

    private static func progress() -> [String: [String: String]] {
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let dict = try? JSONDecoder().decode([String: [String: String]].self, from: data)
        else { return [:] }
        return dict
    }

    private static func saveProgress(_ dict: [String: [String: String]]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    static func completedIndices(for plan: KhatmahPlan) -> Set<Int> {
        Set(progress()[plan.id]?.compactMap { Int($0.key) } ?? [])
    }

    static func completedDate(plan: KhatmahPlan, index: Int) -> String? {
        progress()[plan.id]?[String(index)]
    }

    /// Marks a whole portion done today (per-wird completion).
    /// Returns true when this completion finished the entire plan.
    @discardableResult
    static func completePortion(plan: KhatmahPlan, index: Int) -> Bool {
        var all = progress()
        var entry = all[plan.id] ?? [:]
        entry[String(index)] = dateKey()
        all[plan.id] = entry
        saveProgress(all)
        if index == daysTotal(for: plan) - 1 {
            finishPlan(plan)
            return true
        }
        return false
    }

    /// Undo the last completion for a plan portion.
    static func undoPortion(plan: KhatmahPlan, index: Int) {
        var all = progress()
        all[plan.id]?.removeValue(forKey: String(index))
        saveProgress(all)
    }

    enum PlanState {
        case notStarted
        case inProgress(completed: Int, total: Int, todayIndex: Int)
        case finished
    }

    static func state(for plan: KhatmahPlan) -> PlanState {
        guard plan.active else {
            return history().contains(where: { $0.id == plan.id }) ? .finished : .notStarted
        }
        let done = completedIndices(for: plan).count
        let total = daysTotal(for: plan)
        return .inProgress(completed: done, total: total, todayIndex: todayIndex(for: plan))
    }

    // MARK: - Completion history (completedKhatmahs.v1)

    static func history() -> [KhatmahCompleted] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let list = try? JSONDecoder().decode([KhatmahCompleted].self, from: data)
        else { return [] }
        return list
    }

    private static func saveHistory(_ list: [KhatmahCompleted]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    /// Finishes a plan: deactivates it, archives it in the history and
    /// arms the completion-duaa sheet for the next time the feature opens.
    static func finishPlan(_ plan: KhatmahPlan) {
        var list = plans()
        for i in list.indices where list[i].id == plan.id { list[i].active = false }
        savePlans(list)
        var hist = history()
        if !hist.contains(where: { $0.id == plan.id }) {
            hist.insert(KhatmahCompleted(
                id: plan.id,
                name: plan.name,
                pagesPerDay: plan.pagesPerDay,
                daysTotal: daysTotal(for: plan),
                completedAt: Date()), at: 0)
            saveHistory(hist)
        }
        UserDefaults.standard.set(false, forKey: duaaShownKey)
        refreshNotification()
    }

    /// Whether the completion duaa should be presented (shown once per khatmah).
    static func pendingCompletionDuaa() -> Bool {
        !UserDefaults.standard.bool(forKey: duaaShownKey) && !history().isEmpty
    }

    static func markCompletionDuaaShown() {
        UserDefaults.standard.set(true, forKey: duaaShownKey)
    }

    // MARK: - Completion duaa set (khatmahDuaa — 43 baked texts)

    /// The dua/completion texts (baked from the original Khatmah set).
    static var duaaTexts: [String] {
        guard let url = Bundle.main.url(forResource: "khatmah", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String]].self, from: data),
              let texts = raw["portions"]
        else { return [] }
        return texts
    }

    /// Completion dua: random pick from the 43-text set.
    static func completionDuaa() -> String? {
        duaaTexts.randomElement()
    }

    // MARK: - Daily reminder notification
    // settable time → UNCalendarNotificationTrigger, daily repeating.

    private static func notificationTimeMinutes() -> Int? {
        let ud = UserDefaults.standard
        guard ud.bool(forKey: notifEnabledKey) else { return nil }
        return ud.object(forKey: notifTimeKey) as? Int
    }

    static func refreshNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notifIdentifier])
        guard activePlan() != nil, let minutes = notificationTimeMinutes() else { return }
        scheduleNotification(minutes: minutes, center: center)
    }

    static func setNotificationEnabled(_ enabled: Bool, minutes: Int, completion: ((Bool) -> Void)? = nil) {
        UserDefaults.standard.set(enabled, forKey: notifEnabledKey)
        UserDefaults.standard.set(minutes, forKey: notifTimeKey)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notifIdentifier])
        guard enabled, activePlan() != nil else {
            completion?(true)
            return
        }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                guard granted else {
                    UserDefaults.standard.set(false, forKey: notifEnabledKey)
                    completion?(false)
                    return
                }
                scheduleNotification(minutes: minutes, center: center)
                completion?(true)
            }
        }
    }

    private static func scheduleNotification(minutes: Int, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = DikhrStrings.tr("ورد الختمة", "Khatmah Portion")
        content.body = DikhrStrings.tr("لا تنسَ ورد قراءتك اليوم", "Don't forget today's Quran portion")
        content.sound = .default
        var comps = DateComponents()
        comps.hour = (minutes / 60) % 24
        comps.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(
            identifier: notifIdentifier, content: content, trigger: trigger))
    }
}
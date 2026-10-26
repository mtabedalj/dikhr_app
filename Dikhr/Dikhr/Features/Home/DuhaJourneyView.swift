import SwiftUI

// MARK: - Duha journey
//
// Original ground truth (binary strings): Duha is an interactive journey —
// "DuhaJourneyView" with 5 stations, each (title/subtitle/bullet); station 2
// carries the hadith "صلاة الأوّابين حين ترمض الفصال" with source "رواه مسلم"
// (Muslim 856). Completion state per day with undo ("Duha completion supports
// undo", "Undo Duha completion"), day marker "صلّيت الضحى اليوم", and an
// optional duha notification ("PrayerActionResultView — duha notification").
//
// Station content below is verbatim from the original binary's localized
// strings (extracted from /Applications/Athkar.app/Wrapper/athkar.app).
// Completions are persisted per ISO day under "duhaStations.<date>"; finishing
// all five stations marks the day complete (dailyTasks_duhaComplete) and
// checks in the Nawafil streak through StreaksStore. The entry point is the
// existing DuhaCard (wired by the main session).

let dikhrTeal = Color(red: 0x01 / 255.0, green: 0x8F / 255.0, blue: 0x9E / 255.0)

struct DuhaStation: Identifiable {
    let index: Int
    let title: String
    let subtitle: String
    let bullets: [String]
    let notes: [String]
    let hadith: String?
    let hadithSource: String?
    var id: Int { index }
}

let duhaStations: [DuhaStation] = [
    DuhaStation(
        index: 1,
        title: "من الإشراق إلى قُبيل الظهر",
        subtitle: "تبدأ بعد ارتفاع الشمس قِيدَ رمح، أي بعد الشروق بنحو ربع ساعة",
        bullets: ["وتمتد إلى وقوف الشمس قُبيل دخول الظهر"],
        notes: [],
        hadith: nil, hadithSource: nil),
    DuhaStation(
        index: 2,
        title: "حين يشتد الضحى",
        subtitle: "من صلّاها في أول الوقت أو أثنائه فقد أصاب السنة",
        bullets: ["وأفضلها حين يشتد الحرّ"],
        notes: [],
        hadith: "صلاة الأوّابين حين ترمض الفصال",
        hadithSource: "رواه مسلم"),
    DuhaStation(
        index: 3,
        title: "عدد ركعاتها",
        subtitle: "أقلها ركعتان",
        bullets: ["أقلها ركعتان بتسليمة واحدة",
                  "وإن صلّى أربعًا أو ستًا أو ثمانيًا أو أكثر فحسن، يسلّم من كل ركعتين"],
        notes: ["وصلّاها النبي ﷺ ثماني ركعات يوم الفتح"],
        hadith: nil, hadithSource: nil),
    DuhaStation(
        index: 4,
        title: "ما يُقرأ فيها",
        subtitle: "ما تيسّر، بلا تخصيص",
        bullets: ["يقرأ ما تيسّر من الآيات أو السور، ليس فيها شيء مخصوص"],
        notes: [],
        hadith: nil, hadithSource: nil),
    DuhaStation(
        index: 5,
        title: "الشروق والإشراق",
        subtitle: "وقتان يُخلط بينهما",
        bullets: ["الشروق: لحظة طلوع الشمس من الأفق",
                  "الإشراق: بعد ارتفاعها قِيدَ رمح، أي بعد الشروق بنحو ربع ساعة"],
        notes: [],
        hadith: nil, hadithSource: nil),
]

/// Persists per-day Duha journey completion: "duhaStations.<isoDate>" = the
/// set of completed station indices, plus a day-complete marker
/// "dailyTasks_duhaComplete" (ISO date of the last fully-completed day).
enum DuhaJourneyStore {
    private static func key(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return "duhaStations." + f.string(from: date)
    }

    static func completed(for date: Date = Date()) -> Set<Int> {
        Set((UserDefaults.standard.array(forKey: key(for: date)) as? [Int]) ?? [])
    }

    static func setCompleted(_ stations: Set<Int>, for date: Date = Date()) {
        let defaults = UserDefaults.standard
        defaults.set(Array(stations).sorted(), forKey: key(for: date))
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        let marker = defaults.string(forKey: "dailyTasks_duhaComplete")
        let today = f.string(from: date)
        if stations.count == duhaStations.count {
            defaults.set(today, forKey: "dailyTasks_duhaComplete")
        } else if marker == today {
            defaults.removeObject(forKey: "dailyTasks_duhaComplete")
        }
    }

    static func isDayComplete(for date: Date = Date()) -> Bool {
        completed(for: date).count == duhaStations.count
    }
}

struct DuhaJourneyView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var completed: Set<Int> = []

    private var nextStation: Int? {
        (1...duhaStations.count).first { !completed.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        ForEach(duhaStations) { station in
                            stationCard(station)
                                .id(station.index)
                        }
                        if completed.count == duhaStations.count {
                            dayCompleteBanner
                        }
                        // Optional duha notification ("PrayerActionResultView —
                        // duha notification"): toggle lives at the bottom of
                        // the journey, not on the card (the card is the
                        // navigation entry to this page).
                        DuhaNotificationToggleRow()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .onChange(of: completed.count) { _, _ in
                    if let next = nextStation {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(next, anchor: .center)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(settings.t("صلاة الضحى", "Duha Prayer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(settings.t("صلاة الضحى", "Duha Prayer")).font(.headline)
                }
            }
            .onAppear { completed = DuhaJourneyStore.completed() }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(verbatim: settings.t("أفضل وقتها", "Best Time"))
                .font(.title2.bold())
            Text(verbatim: "من الإشراق إلى قُبيل الظهر")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func stationCard(_ station: DuhaStation) -> some View {
        let isDone = completed.contains(station.index)
        let isNext = nextStation == station.index
        // Locked until the previous station is completed — the journey moves
        // in order, matching the original's sequential stations.
        let isLocked = !isDone && !isNext
        return HStack(alignment: .top, spacing: 12) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(isDone ? AnyShapeStyle(dikhrTeal) : AnyShapeStyle(Color(.tertiarySystemFill)))
                    .frame(width: 34, height: 34)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(station.index)")
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(isLocked ? AnyShapeStyle(.tertiary) : AnyShapeStyle(dikhrTeal))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: station.title)
                        .font(.headline)
                        .foregroundStyle(isLocked ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    Text(verbatim: station.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let hadith = station.hadith {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("«\(hadith)»")
                            .font(.system(size: 19))
                            .foregroundStyle(dikhrTeal)
                        if let source = station.hadithSource {
                            Text(verbatim: source)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(dikhrTeal.opacity(0.10)))
                }
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(station.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(dikhrTeal)
                                .padding(.top, 9)
                            Text(verbatim: bullet)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    ForEach(station.notes, id: \.self) { note in
                        Text(verbatim: note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if !isLocked {
                    completeButton(isDone: isDone, station: station)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 24)
            .fill(Color(.secondarySystemGroupedBackground)))
        .opacity(isLocked ? 0.55 : 1)
        .accessibilityHint(isDone ? settings.t("اضغط لتغيير حالة الإنجاز.", "Tap to change completion state.")
                                  : settings.t("المحطة \(station.index) من ٥", "Station \(station.index) of 5"))
    }

    private func completeButton(isDone: Bool, station: DuhaStation) -> some View {
        Button {
            var stations = DuhaJourneyStore.completed()
            if isDone {
                stations.remove(station.index)   // "Undo Duha completion"
            } else {
                stations.insert(station.index)
            }
            DuhaJourneyStore.setCompleted(stations)
            completed = stations
            // Finishing all five stations checks in the Nawafil streak.
            if stations.count == duhaStations.count {
                StreaksStore.setNawafil(true)
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("dikhr-checkin-changed"), object: nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isDone ? "arrow.uturn.backward" : "checkmark.circle")
                Text(verbatim: isDone ? settings.t("تراجع عن الإتمام", "Undo completion")
                                      : settings.t("صلّيت الضحى", "Prayed Duha"))
                Spacer()
            }
            .font(.subheadline.bold())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(isDone ? AnyShapeStyle(dikhrTeal) : AnyShapeStyle(.primary))
    }

    private var dayCompleteBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .foregroundStyle(dikhrTeal)
            Text(settings.t("صلّيت الضحى اليوم", "Duha prayed today"))
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(dikhrTeal.opacity(0.10)))
    }
}
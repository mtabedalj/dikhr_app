import SwiftUI

/// English titles for the AthkarStore category ids (AthkarStore.categoryTitles
/// stays Arabic; the Data store is not touched by the language switch).
private let athkarCategoryEnglishTitles: [String: String] = [
    "Page1": "Morning Athkar",
    "Page2": "Evening Athkar",
    "Page3": "Sleep Athkar",
    "Page31": "Waking-Up Athkar",
    "Page4": "Authentic Supplications",
    "Page5": "Post-Prayer Athkar",
    "Page6": "Miscellaneous Supplications",
    "Page7": "Supplications from the Quran",
    "Page8": "Prophetic Supplications",
    "AkherAyateen": "Closing Verses",
    "RoqiaQuran": "Ruqyah from the Quran",
    "RoqiaSuna": "Ruqyah of the Sunnah",
    "Tasbee7": "Tasbih",
    // Pseudo-categories loaded from mix.json (أدعية شاملة).
    "shamelaAll": "Comprehensive Athkar",
    "shamelaShort": "Summary",
]

extension AthkarCategory {
    /// Title resolved per Arabic/English mode.
    func localizedTitle(_ lang: SettingsStore.Language) -> String {
        lang == .arabic ? title : (athkarCategoryEnglishTitles[id] ?? title)
    }
}

// MARK: - Athkar home (matches the original's أذكار tab home)
//
// Live capture ground truth (/tmp/athkar_live_1.png, /tmp/step_home.png):
//   chips: المنوعة / الصلاة / القبلة / المفضلة / العداد (Vision OCR of the live app)
//   header sky is SOLAR-STATE aware: night = deep-navy starfield, day =
//   bright blue gradient + soft sun glare top-center + faint cloud haze.
//   banner verse by state: night "وَعَلَىٰ رَبِّهِمْ يَتَوَكَّلُونَ",
//   day "إِنَّ ٱلۡمُتَّقِينَ فِي جَنَّٰتٖ وَعُيُونٍ" (Quran.DB exact form,
//   OCR'd from the day capture as جنّاتِ).
//   strip neighbors swap by prayer: night left العشاء 07:52 right الفجر 06:42,
//   day right العصر 04:06 left الظهر 01:18 → right = NEXT prayer,
//   left = PREVIOUS (first child leads right in RTL).
//   countdown row gold: "الفجر بعد 6:54:09" (next prayer, live HH:MM:SS);
//   within ~1h after an adhan it is replaced by the alert banner
//   "مضى على أذان الظهر 53 دقيقة" (format key 'مضى على أذان %@ %@').
//   "المصحف" gold pill + bookmark badge, "متابعة العبادات" card with progress ring
//   two-column pastel category pill grid + green "المزيد" chip
//
// The home is always dark-first (like the original), independent of the device
// scheme; pushed pages keep the system styling.

private let athkarHomeGold = Color(red: 0.79, green: 0.65, blue: 0.35)

/// Per-category pastel accents on dark (fixed map, Arabic-mode exact colors).
private let athkarChipColors: [String: Color] = [
    "allahNames": Color(red: 0.88, green: 0.55, blue: 0.52),   // أسماء الله الحسنى
    "Page1": Color(red: 0.51, green: 0.66, blue: 0.98),         // أذكار الصباح
    "Page2": Color(red: 0.95, green: 0.35, blue: 0.25),         // أذكار المساء
    "Tasbee7": Color(red: 0.51, green: 0.66, blue: 0.98),       // تسابيح
    "Page5": Color(red: 0.56, green: 0.68, blue: 0.97),         // أذكار بعد الصلاة
    "myAthkar": Color(red: 0.30, green: 0.80, blue: 0.78),      // أذكاري
    "Page31": Color(red: 0.91, green: 0.58, blue: 0.80),        // أذكار الاستيقاظ
    "Page3": Color(red: 0.75, green: 0.45, blue: 0.93),         // أذكار النوم
    "Page7": Color(red: 0.70, green: 0.70, blue: 0.72),         // أدعية من القرآن
    "Page8": Color(red: 0.89, green: 0.65, blue: 0.30),         // أدعية النبي ﷺ
    "RoqiaQuran": Color(red: 0.90, green: 0.56, blue: 0.30),    // الرقية بالقرآن
    "RoqiaSuna": Color(red: 0.28, green: 0.74, blue: 0.62),     // الرقية بالسنة
    "AkherAyateen": Color(red: 0.79, green: 0.65, blue: 0.35),  // آيات خاتمة
    "Page4": Color(red: 0.79, green: 0.65, blue: 0.35),         // الأدعية المأثورة
    "Page6": Color(red: 0.70, green: 0.70, blue: 0.72),         // أدعية متفرقة
    "more": Color(red: 0.42, green: 0.78, blue: 0.30)           // المزيد
]

struct AthkarCategoryListView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var categories: [AthkarCategory] = []
    @State private var path = NavigationPath()
    @State private var chip: AthkarHomeChip = .all
    @State private var ringRatio: Double = 0
    @State private var now = Date()
    @State private var nameCount = 0
    @State private var shamelahMix: [AthkarEntry] = []
    @State private var shamelahShort: [AthkarEntry] = []
    @State private var tickerIndex = 0
    @State private var showSettingsSheet = false

    private let tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: chip row / filter

    enum AthkarHomeChip: CaseIterable, Equatable {
        case all, prayer, qibla, favorites, counter

        func title(_ lang: SettingsStore.Language) -> String {
            switch self {
            case .all: return lang == .arabic ? "المنوعة" : "All"
            case .prayer: return lang == .arabic ? "الصلاة" : "Prayer"
            case .qibla: return lang == .arabic ? "القبلة" : "Qibla"
            case .favorites: return lang == .arabic ? "المفضلة" : "Favorites"
            case .counter: return lang == .arabic ? "العداد" : "Counter"
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color(red: 0.045, green: 0.045, blue: 0.055).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        skyHeader
                        prayerStrip
                        chipRow
                        countdownRow
                        mushafRow
                        mutabaatCard
                        categoryGrid
                    }
                    .padding(.bottom, 24)
                }
                .ignoresSafeArea(edges: .top)
                .toolbar(.hidden, for: .navigationBar)
            }
            .navigationDestination(for: AthkarCategory.self) { category in
                AthkarPageView(category: category)
            }
            .navigationDestination(for: String.self) { key in
                switch key {
                case "allahNames": AllahNamesView()
                case "myAthkar": MyAthkarView()
                case "khatmah": KhatmahView()
                case "qibla": QiblaView()
                case "salahPage": AthkarSalahPageView()
                case "favorites": AthkarFavoritesView()
                case "followupPage": AthkarFollowupView()
                case "search": AthkarSearchPageView()
                case "more": AthkarMoreGridPage()
                case "adhanHistory": AdhanHistoryView()
                default: AthkarSearchPageView()
                }
            }
            .onAppear {
                if categories.isEmpty {
                    categories = AthkarStore.loadCategories()
                    nameCount = AthkarStore.loadNinetyNineNames().count
                    shamelahMix = athkarShamelahEntries("Mix")
                    shamelahShort = athkarShamelahEntries("ShortMix")
                    let day = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
                    tickerIndex = day % athkarHomeTickerTexts.count
                }
                refreshRing()
                if let push = ProcessInfo.processInfo.environment["DIKHR_PUSH"] {
                    switch push {
                    case "allahNames", "myAthkar", "khatmah", "favorites", "search", "more":
                        path.append(push)
                    default:
                        if let target = categories.first(where: { $0.id == push }) {
                            path.append(target)
                        }
                    }
                }
                if ProcessInfo.processInfo.environment["DIKHTML_LISTEN"] != nil ||
                   ProcessInfo.processInfo.environment["DIKHR_LISTEN"] != nil,
                   let target = categories.first(where: { $0.id == "Page1" }) {
                    path.append(target)
                }
            }
            .onReceive(tickTimer) { now = $0 }
            .onReceive(NotificationCenter.default.publisher(
                for: NSNotification.Name("dikhr-checkin-changed"))) { _ in
                refreshRing()
            }
            // The gear button (like the original) opens the SETTINGS BOTTOM SHEET,
            // not the settings tab. (.presentation modifiers live inside the view.)
            .sheet(isPresented: $showSettingsSheet) {
                SettingsSheetView()
            }
        }
    }

    private func refreshRing() {
        let day = StreaksStore.today()
        let done = [day.prayers, day.quran, day.nawafil, day.athkarCount > 0].filter { $0 }.count
        ringRatio = Double(done) / 4.0
    }

    // MARK: 1. sky header (night starfield / day sun glare, solar-state aware)

    /// Night between isha and the next fajr (HomeCards.resolveTimes), day in
    /// between — picks the header sky AND its verse, like the original.
    private var isNightSky: Bool {
        guard let t = prayerTimes else { return true }
        return now < t.fajr || now > t.isha
    }

    /// Header banner verse per state (captured verbatim; day form matches
    /// Dikhr's Quran.sqlite 15:45/51:15 exactly).
    private var headerVerse: String {
        isNightSky ? "وَعَلَىٰ رَبِّهِمْ يَتَوَكَّلُونَ"
                   : "إِنَّ ٱلۡمُتَّقِينَ فِي جَنَّٰتٖ وَعُيُونٍ"
    }

    private var skyHeader: some View {
        ZStack {
            if isNightSky { nightSky } else { daySky }
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Spacer()
                    homeCircleButton("gearshape.fill", action: {
                        showSettingsSheet = true
                    })
                    homeCircleButton("magnifyingglass", action: { path.append("search") })
                    homeCircleButton("bookmark", action: { path.append("favorites") })
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)
                Spacer()
                Text(headerVerse)
                    .font(.custom("KFGQPCHAFSUthmanicScript-Bold", size: 30))
                    .foregroundStyle(Color(red: 0.97, green: 0.95, blue: 0.90))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }
        }
    }

    /// Night sky: deep-navy gradient + deterministic star specks.
    private var nightSky: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.105, blue: 0.19),
                                    Color(red: 0.07, green: 0.075, blue: 0.14),
                                    Color(red: 0.03, green: 0.031, blue: 0.058)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 265)
            GeometryReader { geo in
                ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, star in
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.r, height: star.r)
                        .position(x: geo.size.width * star.x, y: 265 * star.y)
                }
            }
            .frame(height: 265)
        }
    }

    /// Day sky (pixel-sampled from /tmp/step_home.png): blue ramp darkest at
    /// the top (35,63,128) → soft (74,115,183) at the bottom, a compact warm
    /// sun glare just under the top-center edge plus a wide pale haze, and
    /// faint cloud wisps near the top.
    private var daySky: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.137, green: 0.247, blue: 0.502),
                                    Color(red: 0.29, green: 0.45, blue: 0.72)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 265)
            GeometryReader { geo in
                ZStack {
                    RadialGradient(colors: [Color(red: 0.93, green: 0.93, blue: 0.85).opacity(0.85),
                                            Color.clear],
                                   center: UnitPoint(x: 0.49, y: 0.05),
                                   startRadius: 0,
                                   endRadius: geo.size.width * 0.15)
                    RadialGradient(colors: [Color(red: 0.85, green: 0.90, blue: 0.97).opacity(0.30),
                                            Color.clear],
                                   center: UnitPoint(x: 0.49, y: 0.16),
                                   startRadius: 0,
                                   endRadius: geo.size.width * 0.34)
                    ForEach(Array(Self.clouds.enumerated()), id: \.offset) { _, cloud in
                        Ellipse()
                            .fill(Color.white.opacity(cloud.opacity))
                            .frame(width: geo.size.width * cloud.w, height: cloud.h)
                            .blur(radius: cloud.blur)
                            .position(x: geo.size.width * cloud.x, y: 265 * cloud.y)
                    }
                }
            }
            .frame(height: 265)
        }
    }

    /// Deterministic star specks (fractional positions within the header).
    private static let stars: [(x: Double, y: Double, r: Double, opacity: Double)] = [
        (0.07, 0.10, 2.0, 0.55), (0.19, 0.28, 1.4, 0.40), (0.28, 0.09, 2.4, 0.60),
        (0.38, 0.55, 1.2, 0.35), (0.46, 0.20, 1.6, 0.45), (0.52, 0.72, 1.4, 0.30),
        (0.61, 0.08, 2.2, 0.55), (0.67, 0.40, 1.2, 0.35), (0.74, 0.22, 1.8, 0.50),
        (0.81, 0.62, 1.3, 0.30), (0.87, 0.13, 2.6, 0.60), (0.93, 0.34, 1.4, 0.40),
        (0.14, 0.62, 1.3, 0.28), (0.44, 0.86, 1.6, 0.25), (0.71, 0.82, 1.2, 0.22),
        (0.95, 0.75, 1.5, 0.25)
    ]

    /// Deterministic faint cloud wisps for the day sky (fractions of the header).
    private static let clouds: [(x: Double, y: Double, w: Double, h: Double, opacity: Double, blur: Double)] = [
        (0.28, 0.14, 0.30, 30, 0.05, 10),
        (0.72, 0.11, 0.26, 26, 0.04, 10),
        (0.50, 0.28, 0.42, 34, 0.06, 12),
        (0.83, 0.32, 0.22, 22, 0.04, 10),
        (0.14, 0.26, 0.24, 24, 0.045, 10)
    ]

    private func homeCircleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    // MARK: 2. prayer anchor strip + hijri medallion

    private var prayerStrip: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color(red: 0.075, green: 0.075, blue: 0.088))
                .frame(height: 58)
            HStack(spacing: 8) {
                // RTL: first child leads on the RIGHT = NEXT prayer, the second
                // side (left) = PREVIOUS — day capture: العصر 04:06 right,
                // الظهر 01:18 left; night capture: الفجر 06:42 right,
                // العشاء 07:52 left.
                if let next = nextPrayer {
                    stripTime(settings.t(next.kind.arabicName, next.kind.englishName),
                              hhColonMM(next.date))
                }
                Spacer()
                medallion
                Spacer()
                if let previous = previousPrayer {
                    stripTime(settings.t(previous.kind.arabicName, previous.kind.englishName),
                              hhColonMM(previous.date))
                }
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: 58)
        }
    }

    private var prayerTimes: PrayerTimes? {
        HomeCards.resolveTimes(settings: settings, now: now)
    }

    private func stripTime(_ name: String, _ time: String) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.white)
            Text(time)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .fixedSize()
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }

    private func hhColonMM(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d : %02d", c.hour ?? 0, c.minute ?? 0)
    }

    private var medallion: some View {
        let h = HomeHijri.components(for: now, adjustment: settings.hijriAdjustment)
        let englishMonths = ["Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
                             "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
                             "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"]
        let month = (1...12).contains(h.month)
            ? (settings.lang == .arabic ? HomeHijri.months[h.month - 1] : englishMonths[h.month - 1])
            : ""
        return VStack(spacing: 1) {
            Text("\(h.day)")
                .font(.system(size: 19, weight: .bold))
                .monospacedDigit()
            Text(month)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color(red: 0.92, green: 0.92, blue: 0.94))
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 15)
            .fill(Color(red: 0.16, green: 0.16, blue: 0.18)))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.10)))
        .offset(y: -19)
    }

    // MARK: 3. chip row

    private var chipRow: some View {
        HStack(spacing: 0) {
            ForEach(AthkarHomeChip.allCases, id: \.self) { c in
                Button {
                    switch c {
                    case .qibla:
                        path.append("qibla")
                    case .favorites:
                        path.append("favorites")
                    case .counter:
                        // العداد opens the متابعة والعداد page (real-app evidence),
                        // not the counter tab.
                        path.append("followupPage")
                    case .prayer:
                        // الصلاة chip pushes the full-screen prayer page.
                        path.append("salahPage")
                    case .all:
                        chip = c
                    }
                } label: {
                    Text(c.title(settings.lang))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(chip == c ? Color.white : Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .background(Color(red: 0.028, green: 0.028, blue: 0.033))
    }

    // MARK: 4. gold countdown row / since-adhan banner
    //
    // The first-hour slot under the chip row: within ~1h after an adhan the
    // original shows the alert banner "مضى على أذان الظهر 53 دقيقة"
    // (ar.lproj format key 'مضى على أذان %@ %@', minutes-in-words), otherwise
    // the gold HH:MM:SS countdown to the next prayer (night capture).

    @ViewBuilder
    private var countdownRow: some View {
        if let previous = previousPrayer,
           (1...59).contains(sinceAdhanMinutes(previous.date)) {
            sinceAdhanBanner(previous)
        } else {
            goldCountdown
        }
    }

    private var goldCountdown: some View {
        HStack(spacing: 8) {
            if let next = nextPrayer {
                Text(settings.lang == .arabic
                     ? "\(settings.t(next.kind.arabicName, next.kind.englishName)) بعد"
                     : "\(settings.t(next.kind.arabicName, next.kind.englishName)) in")
                    .font(.system(size: 22, weight: .semibold))
                Text(hms(next.date.timeIntervalSince(now)))
                    .font(.system(size: 22, weight: .semibold))
                    .monospacedDigit()
            }
            Spacer()
        }
        .foregroundStyle(athkarHomeGold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    /// Whole minutes elapsed since the previous prayer's athan.
    private func sinceAdhanMinutes(_ date: Date) -> Int {
        Int(now.timeIntervalSince(date) / 60)
    }

    /// Minutes-in-words; 53 → "53 دقيقة" (matches the capture's banner).
    private func adhanMinutesWords(_ minutes: Int) -> String {
        switch minutes {
        case 1: return "دقيقة"
        case 2: return "دقيقتين"
        case 3...10: return "\(minutes) دقائق"
        default: return "\(minutes) دقيقة"
        }
    }

    private func adhanMinutesWordsEN(_ minutes: Int) -> String {
        minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    /// Alert banner: dark card, white bold text, thin red accent bar on the
    /// leading edge (right, RTL-first child — like the capture), tap → the
    /// elapsed-adhan history page.
    private func sinceAdhanBanner(_ previous: StripEvent) -> some View {
        NavigationLink(value: "adhanHistory") {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color(red: 0.80, green: 0.17, blue: 0.20))
                    .clipShape(Capsule())
                    .frame(width: 3.5, height: 30)
                Text(settings.lang == .arabic
                     ? String(format: "مضى على أذان %@ %@",
                              settings.t(previous.kind.arabicName, previous.kind.englishName),
                              adhanMinutesWords(sinceAdhanMinutes(previous.date)))
                     : String(format: "%@ athan was %@ ago",
                              settings.t(previous.kind.arabicName, previous.kind.englishName),
                              adhanMinutesWordsEN(sinceAdhanMinutes(previous.date))))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.055, green: 0.055, blue: 0.062)))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private struct StripEvent: Equatable {
        let kind: PrayerKind
        let date: Date
    }

    /// Previous (most recent past) and next (first upcoming) prayer around
    /// now — mirrors AthkarSalahPageView's intervalPrayer: prayers only
    /// (sunrise excluded) spanning yesterday/today/tomorrow, so late-night
    /// hours resolve to yesterday's isha → today's fajr. Drives the strip's
    /// neighbor times AND the since-adhan banner.
    private var stripEvents: (prev: StripEvent?, next: StripEvent?) {
        guard let method = HomeCards.resolveMethod(settings: settings) else { return (nil, nil) }
        func events(on date: Date) -> [StripEvent] {
            let t = PrayerTimesEngine.calculate(
                method: method, lat: settings.currentCity.lat, lng: settings.currentCity.lng,
                date: date, timeZone: .current)
            return [StripEvent(kind: .fajr, date: t.fajr),
                    StripEvent(kind: .dhuhr, date: t.dhuhr),
                    StripEvent(kind: .asr, date: t.asr),
                    StripEvent(kind: .maghrib, date: t.maghrib),
                    StripEvent(kind: .isha, date: t.isha)]
        }
        let cal = Calendar.current
        var all = events(on: cal.date(byAdding: .day, value: -1, to: now) ?? now)
        all += events(on: now)
        all += events(on: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        return (all.last { $0.date <= now }, all.first { $0.date > now })
    }

    private var previousPrayer: StripEvent? { stripEvents.prev }

    private var nextPrayer: (kind: PrayerKind, date: Date)? {
        stripEvents.next.map { ($0.kind, $0.date) }
    }

    /// Under one hour the original renders mm:ss ("31:00"), otherwise h:mm:ss.
    private func hms(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        if s < 3600 {
            return String(format: "%02d:%02d", s / 60, s % 60)
        }
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    // MARK: 5. mushaf pill + worship tracker card

    private var mushafRow: some View {
        Button {
            DeepLinkRouter.shared.pendingTab = "quran"
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(settings.t("المصحف", "Mushaf"))
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Text("\(athkarMushafBadge)")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(athkarHomeGold)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(athkarHomeGold.opacity(0.15)))
            }
            .foregroundStyle(athkarHomeGold)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 22)
                .fill(Color(red: 0.055, green: 0.055, blue: 0.062)))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top, 6)
    }

    private var athkarMushafBadge: Int {
        max(1, QuranBookmarkStore.bookmarks().count)
    }

    private var mutabaatCard: some View {
        NavigationLink {
            StreaksDetailView()
        } label: {
            HStack(spacing: 14) {
                worshipRing
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(settings.t("متابعة العبادات", "Worship Tracker"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text(settings.t("تجريبي", "Beta"))
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    Text(settings.t("تتبع صلواتك وأذكارك ونوافلك",
                                    "Track your prayers, athkar and nawafil"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22)
                .fill(Color(red: 0.055, green: 0.055, blue: 0.062)))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var worshipRing: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.16), lineWidth: 5)
            Circle()
                .trim(from: 0, to: ringRatio)
                .stroke(athkarHomeGold, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(ringRatio * 100))%")
                .font(.footnote.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: 62, height: 62)
    }

    // MARK: 6. category grid

    /// Grid order mirrors the capture (RTL pairs), then المزيد.
    private var gridOrder: [String] {
        switch chip {
        case .all:
            // Exact sequence of the original's home grid (RTL pairs,
            // live-verified 2026-10-27). أذكار الصلاة has no offline content
            // in the original's bundle (a v10 remote row) — its label opens
            // the post-prayer adhkar, the closest shipped content.
            return ["allahNames", "Page1", "Page2", "Tasbee7", "salahAlias",
                    "myAthkar", "Page5", "Page3", "Page7", "Page6",
                    "Page8", "RoqiaSuna", "RoqiaQuran", "AkherAyateen", "more"]
        case .prayer:
            return ["Page5"]
        case .qibla, .favorites, .counter:
            return []
        }
    }

    /// Grid continuation (live capture 2): below المزيد — RTL pairs of the
    /// comprehensive-athkar section, then the hadith ticker, crown divider and
    /// the Pro rows. Locked rows = features Dikhr does not re-implement.
    private var gridTailFree: [String] {
        ["shamelaSections", "shamelaShort", "lockedSick", "lockedTayseer",
         "lockedMayyit", "ayaTafseer"]
    }

    /// Pro rows under the crown divider (right column first, RTL), all locked.
    private var gridTailPro: [String] {
        ["lockedDate", "lockedAhbab", "lockedKids", "lockedUmra",
         "lockedHajj", "lockedCard", "lockedBooklet", "lockedWidget"]
    }

    private var shamelahAllCategory: AthkarCategory? {
        shamelahMix.isEmpty ? nil : AthkarCategory(id: "shamelaAll",
                                                   title: "أدعية شاملة",
                                                   entries: shamelahMix)
    }

    private func gridTitle(_ id: String) -> String {
        switch id {
        case "allahNames": return settings.t("أسماء اللّٰه الحسنى", "Names of Allah")
        case "myAthkar": return settings.t("أذكاري", "My Athkar")
        case "more": return settings.t("المزيد", "More")
        case "salahAlias": return settings.t("أذكار الصلاة", "Prayer Athkar")
        // Free continuation rows with an existing Dikhr feature
        case "shamelaSections", "shamelaAll":
            return settings.t("أقسام الأدعية", "Sections")
        case "shamelaShort": return settings.t("مختصر الأدعية", "Summary")
        case "ayaTafseer": return settings.t("أية وتفسير", "Verse and interpretation")
        // Pro/locked rows — original titles (Original Localizable.strings evidence)
        case "lockedSick": return settings.t("أدعية المريض", "Duaas for the sick")
        case "lockedTayseer": return settings.t("أدعية التيسير", "Duaas for ease")
        case "lockedMayyit": return settings.t("أدعية الميت", "Supplications for the deceased")
        case "lockedDate": return settings.t("التاريخ", "Dates")
        case "lockedAhbab": return settings.t("أذكار الأحبة", "Athkar for loved ones")
        case "lockedKids": return settings.t("أذكار للصغار", "Athkar for kids")
        case "lockedUmra": return settings.t("العمرة", "Umrah")
        case "lockedHajj": return settings.t("الحج", "Hajj")
        case "lockedCard": return settings.t("بطاقة الأذكار", "Athkar Cards")
        case "lockedBooklet": return settings.t("كتيب الأذكار", "Athkar Booklet")
        case "lockedWidget": return settings.t("أدعية في الويدجت", "Duaas in the widget")
        default: return categories.first(where: { $0.id == id })?.localizedTitle(settings.lang) ?? id
        }
    }

    private func gridCount(_ id: String) -> Int? {
        switch id {
        case "allahNames": return nameCount
        case "shamelaSections", "shamelaShort": return nil
        case "myAthkar", "more": return nil
        default:
            if id.hasPrefix("locked") || id == "ayaTafseer" { return nil }
            return categories.first(where: { $0.id == id })?.entries.count
        }
    }

    private var categoryGrid: some View {
        VStack(spacing: 14) {
            // 1. the original first rows (unchanged)
            gridChipSection(gridOrder)
            // 2. full-width أدعية شاملة row (capture: one wide pill, two labels)
            shamelahWideRow
            // 3. free continuation cells
            gridChipSection(gridTailFree)
            // 4. hadith ticker strip
            athkarHomeTicker
            // 5. gold crown divider
            crownDivider
            // 6. Pro rows (locked)
            gridChipSection(gridTailPro)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    private func gridChipSection(_ ids: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible())], spacing: 14) {
            ForEach(ids, id: \.self) { id in
                if id.hasPrefix("locked") {
                    // Pro/absent feature: inert, secondary style + lock.
                    proChipBody(id: id)
                } else if id == "ayaTafseer" {
                    // أية وتفسير → existing Quran feature (Tafseer on long press).
                    Button(action: { DeepLinkRouter.shared.pendingTab = "quran" }) {
                        gridChipBody(id: id)
                    }
                    .buttonStyle(.plain)
                } else if id == "salahAlias", let page5 = categories.first(where: { $0.id == "Page5" }) {
                    // The original's v10 remote row "أذكار الصلاة"; offline
                    // content isn't in their bundle, so this opens the shipped
                    // post-prayer adhkar (the overlapping content).
                    NavigationLink(value: AthkarCategory(id: "salahAlias",
                                                         title: gridTitle("salahAlias"),
                                                         entries: page5.entries)) {
                        gridChipBody(id: id)
                    }
                    .buttonStyle(.plain)
                } else if id == "shamelaSections", let category = shamelahAllCategory {
                    NavigationLink(value: category) {
                        gridChipBody(id: id)
                    }
                    .buttonStyle(.plain)
                } else if id == "shamelaAll", let category = shamelahAllCategory {
                    NavigationLink(value: category) {
                        gridChipBody(id: id)
                    }
                    .buttonStyle(.plain)
                } else if id == "shamelaShort", !shamelahShort.isEmpty {
                    NavigationLink(value: AthkarCategory(id: "shamelaShort",
                                                         title: "مختصر الأدعية",
                                                         entries: shamelahShort)) {
                        gridChipBody(id: id)
                    }
                    .buttonStyle(.plain)
                } else if id == "more",
                          let target = AthkarHomeChipTarget(rawValue: "more") {
                    Button(action: { path.append(target.route) }) {
                        gridChipBody(id: id)
                    }
                    .buttonStyle(.plain)
                } else if let category = categories.first(where: { $0.id == id }) {
                    NavigationLink(value: category) {
                        gridChipBody(id: id)
                    }
                    .buttonStyle(.plain)
                } else if let target = AthkarHomeChipTarget(rawValue: id) {
                    Button(action: { path.append(target.route) }) {
                        gridChipBody(id: id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Full-width wide row right above the ticker (matching the capture).
    private var shamelahWideRow: some View {
        HStack(spacing: 10) {
            if let category = shamelahAllCategory {
                NavigationLink(value: category) {
                    Text(settings.t("أدعية شاملة", "Comprehensive Athkar"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if !shamelahShort.isEmpty {
                NavigationLink(value: AthkarCategory(id: "shamelaShort",
                                                     title: "مختصر الأدعية",
                                                     entries: shamelahShort)) {
                    Text(settings.t("أدعية شاملة في صفحة واحدة",
                                    "Comprehensive supplications on one page"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 17)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(Color(red: 0.055, green: 0.055, blue: 0.062))
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.16))))
    }

    /// Rounded dark strip showing ONE hadith snippet; taps cycle through the
    /// static list. Rotates daily (dayIndex % count), no persistence.
    private var athkarHomeTicker: some View {
        Button {
            tickerIndex = (tickerIndex + 1) % athkarHomeTickerTexts.count
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text(athkarHomeTickerTexts[tickerIndex % athkarHomeTickerTexts.count])
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.125, green: 0.125, blue: 0.14))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.10))))
        }
        .buttonStyle(.plain)
    }

    /// Hairline — gold crown — hairline, before the Pro rows.
    private var crownDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(athkarHomeGold.opacity(0.4))
                .frame(height: 0.7)
            Image(systemName: "crown.fill")
                .font(.system(size: 12))
                .foregroundStyle(athkarHomeGold)
            Rectangle()
                .fill(athkarHomeGold.opacity(0.4))
                .frame(height: 0.7)
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
    }

    /// Pro row: secondary text + lock glyph, inert (no invented page).
    private func proChipBody(id: String) -> some View {
        HStack(spacing: 6) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
            Text(gridTitle(id))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 15)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(Color(red: 0.055, green: 0.055, blue: 0.062))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.14))))
    }

    @ViewBuilder
    private func gridChipBody(id: String) -> some View {
        let color = athkarChipColors[id] ?? .white
        HStack(spacing: 6) {
            Spacer()
            Text(gridTitle(id))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if id == "Page8" {
                Text("ﷺ")
                    .font(.system(size: 11))
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 15)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(Color(red: 0.055, green: 0.055, blue: 0.062))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.28))))
    }
}

/// String routes reachable from the athkar home grid.
private enum AthkarHomeChipTarget: String {
    case allahNames, myAthkar, more

    var route: String { rawValue }
}

/// Hadith snippets for the home ticker. All six appear verbatim in the
/// original app's binary (prayer-hadith list + the البقرة ticker literal);
/// classical sources, public domain.
private let athkarHomeTickerTexts: [String] = [
    "من قرأ الآيتين من آخر سورة البقرة في ليلة كفتاه. (رواه البخاري)",
    "من صلى البردين دخل الجنة. (رواه البخاري)",
    "لن يلج النار أحد صلى قبل طلوع الشمس وقبل غروبها. (رواه مسلم)",
    "من صلى الصبح في جماعة فكأنما صلى الليل كله. (رواه مسلم)",
    "رَكْعتا الفجْرِ (سنة الفجر) خيْرٌ مِنَ الدُّنيا ومَا فِيها. (رواه مسلم)",
    "من حافظ على الأربع قبل الظهر، وأربع بعدها، حرّمه الله على النار. (رواه أبو داود)",
]

/// Load one list from the bundled mix.json ("Mix" / "ShortMix") as athkar
/// entries — the original's الأدعية الشاملة data, already converted.
private func athkarShamelahEntries(_ key: String) -> [AthkarEntry] {
    guard let url = Bundle.main.url(forResource: "mix", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [String]],
          let list = raw[key]
    else { return [] }
    return list.map { text in
        AthkarEntry(Title: nil, Athkar: text, Count: nil, Audio: nil)
    }
}

/// Favorite identity scheme shared with AthkarPageView.
private func athkarFavoriteID(_ category: AthkarCategory, _ entry: AthkarEntry) -> String {
    let fallback = String(AthkarStore.stripHTML(entry.Athkar ?? "").prefix(24))
    return "\(category.id)|\(entry.Title ?? fallback)"
}

// MARK: - Pushed helper pages (favorites / search / all sections)

/// المفضلة — entries starred in AthkarPageView (same favoriteID scheme).
struct AthkarFavoritesView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var categories: [AthkarCategory] = []

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.045).ignoresSafeArea()
            List {
            ForEach(favoriteGroups, id: \.category.id) { group in
                Section(group.category.localizedTitle(settings.lang)) {
                    ForEach(group.entries, id: \.id) { entry in
                        NavigationLink {
                            AthkarPageView(category: group.category)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.Title ?? "")
                                    .font(.headline)
                                Text(AthkarStore.stripHTML(entry.Athkar ?? ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            }
        }
        .overlay {
            if favoriteGroups.isEmpty {
                Text(settings.t("لا يوجد دعاء في المفضلة. لإضافة دعاء هنا اذهب إلى صفحة الأذكار ونضغط على زر النجمة.",
                                "No favorites yet. Open an athkar page and tap the star to add one."))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
            }
        }
        .navigationTitle(settings.t("المفضلة", "Favorites"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if categories.isEmpty { categories = AthkarStore.loadCategories() }
        }
    }

    private struct Group {
        let category: AthkarCategory
        let entries: [AthkarEntry]
    }

    private var favoriteGroups: [Group] {
        categories.map { category in
            Group(category: category,
                  entries: category.entries.filter {
                      settings.favorites.contains(athkarFavoriteID(category, $0))
                  })
        }
        .filter { !$0.entries.isEmpty }
    }
}

/// البحث — the original's full-screen dark search page (black bg, centered
/// white title, back chevron top-right, pill search bar, and grouped results):
///
/// Live captures (/tmp/athkar_search.png empty, /tmp/athkar_search_results.png
/// with "استغفر الله"):
///   - pill bar: dark rounded field, magnifier at the right end, gray
///     placeholder "ابحث ..." right-aligned; the LEFT end holds a small
///     circular button — empty query: gold sparkles inside a pink/purple
///     gradient ring (their "AI search"); text present: solid gray ✕ (clear).
///   - results grouped under gold right-aligned headers ("المصحف" for Quran
///     matches, page title for athkar matches); each row: gold bold title
///     + gray "آية 106" meta, snippet below in Uthmanic (Quran) or
///     Scheherazade (athkar), a left "<" chevron; tap opens the target.
///
/// The original's AI search service is not replicable; the honest local
/// mapping is that smart matching is ALWAYS on: the query is stripped of
/// diacritics/tatweel before it runs (plus an alef/hamza/ya-unified retry,
/// which also matches how Quran.sqlite's `search_text` normalized ٱ), and
/// athkar matching normalizes both sides. The sparkle button re-runs that
/// search; the ✕ clears the field.
struct AthkarSearchPageView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var categories: [AthkarCategory] = []
    @State private var quranResults: [QuranAyah] = []
    @State private var athkarGroups: [AthkarGroup] = []
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                searchBar
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                results
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if categories.isEmpty {
                categories = AthkarStore.loadCategories()
            }
            runSearch()
            fieldFocused = true
        }
        .onChange(of: query) { _, _ in runSearch() }
    }

    // MARK: chrome

    private var topBar: some View {
        ZStack {
            Text(settings.t("البحث", "Search"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            HStack {
                Spacer()
                // Same dark round chevron as AthkarSalahPageView's back button.
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 18)
        }
        .padding(.top, 34)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            // RTL: the magnifier leads at the right end (like the capture).
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            TextField(settings.t("ابحث ...", "Search ..."), text: $query)
                .focused($fieldFocused)
                .submitLabel(.search)
                .font(.system(size: 17))
            smartButton
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 23)
            .fill(Color(white: 0.075))
            .overlay(RoundedRectangle(cornerRadius: 23)
                .stroke(Color.white.opacity(0.16))))
    }

    /// Left end of the bar: sparkles in a gradient ring until the field has
    /// text — tap re-runs the (always-normalized) smart search — then the
    /// gray ✕ clear button.
    @ViewBuilder
    private var smartButton: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            Button(action: { runSearch() }) {
                ZStack {
                    Circle().stroke(LinearGradient(colors: [Color(red: 0.93, green: 0.42, blue: 0.72),
                                                            Color(red: 0.55, green: 0.48, blue: 0.95)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1.6)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(athkarHomeGold)
                }
                .frame(width: 27, height: 27)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: { query = "" }) {
                ZStack {
                    Circle().fill(Color(white: 0.35))
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: 27, height: 27)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: results

    @ViewBuilder
    private var results: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            // The empty state is a blank black area (capture 1).
            Spacer().frame(maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    if !quranResults.isEmpty {
                        QuranResultGroup(title: settings.t("المصحف", "Mushaf"), ayahs: quranResults)
                    }
                    ForEach(athkarGroups) { group in
                        AthkarResultGroup(category: group.category, entries: group.entries)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: search pipeline (always-on Arabic normalization)

    private struct AthkarGroup: Identifiable {
        let category: AthkarCategory
        let entries: [AthkarEntry]
        var id: String { category.id }
    }

    private func runSearch() {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else {
            quranResults = []
            athkarGroups = []
            return
        }
        // Quran: QuranDatabase runs LIKE against the pre-normalized
        // `search_text` column (diacritics stripped, ٱ → ا), so pass the
        // stripped query; if nothing matched, retry once with the fully
        // unified form (alef/hamza/ya) the user might have typed.
        let stripped = searchStripDiacritics(needle)
        quranResults = QuranDatabase.shared.search(stripped, limit: 30)
        if quranResults.isEmpty && needle.count > 2 {
            quranResults = QuranDatabase.shared.search(searchNormalize(stripped), limit: 30)
        }
        // Athkar: full normalization on BOTH sides (entry text + title vs query).
        let normalized = searchNormalize(needle)
        athkarGroups = categories.compactMap { category in
            let matches = category.entries.filter { entry in
                searchNormalize(AthkarStore.stripHTML(entry.Athkar ?? "")).contains(normalized)
                || searchNormalize(entry.Title ?? "").contains(normalized)
            }
            return matches.isEmpty ? nil : AthkarGroup(category: category, entries: matches)
        }
    }
}

// MARK: - Arabic normalization helpers (search page, local to this file)

/// Strip Arabic diacritics + tatweel, keep hamza letters as typed: matches
/// exactly the normalization Quran.sqlite's `search_text` column uses
/// ("وَٱسۡتَغۡفِرِ" → "واستغفر", "إِنَّ" → "إن" with the alef hamza kept).
private func searchStripDiacritics(_ text: String) -> String {
    text.unicodeScalars.reduce(into: String()) { out, scal in
        if !searchIsMark(scal) { out.unicodeScalars.append(scal) }
    }
}

/// Aggressive smart-match form: also unify ٱأإآ → ا and ى/ئ → ي, so a freely
/// typed query finds entries regardless of hamza/maqsura spelling.
private func searchNormalize(_ text: String) -> String {
    text.unicodeScalars.reduce(into: String()) { out, scal in
        let mapped: UnicodeScalar
        switch scal.value {
        // ٱأإآٲٳ → ا
        case 0x0671, 0x0623, 0x0625, 0x0622, 0x0672, 0x0673: mapped = "ا"
        // ىئ → ي
        case 0x0649, 0x0626: mapped = "ي"
        // ؤ → و
        case 0x0624: mapped = "و"
        default: mapped = scal
        }
        if !searchIsMark(mapped) { out.unicodeScalars.append(mapped) }
    }
}

/// Diacritic/mark/tatweel range check on a (possibly mapped) scalar.
private func searchIsMark(_ scal: UnicodeScalar) -> Bool {
    (0x064B...0x065F).contains(scal.value)
        || scal.value == 0x0670
        || (0x06D6...0x06ED).contains(scal.value)
        || scal.value == 0x0640
}

// MARK: - Result groups + rows (capture 2 layout)

private struct QuranResultGroup: View {
    @EnvironmentObject private var settings: SettingsStore
    let title: String
    let ayahs: [QuranAyah]

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(athkarHomeGold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
            ForEach(ayahs) { ayah in
                QuranResultRow(ayah: ayah)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
            }
        }
    }
}

/// One Quran match: gold surah title + gray "آية 106" meta, full ayah below in
/// Uthmanic, left chevron. Tap pushes the printed mushaf on that ayah's page.
private struct QuranResultRow: View {
    @EnvironmentObject private var settings: SettingsStore
    let ayah: QuranAyah

    var body: some View {
        NavigationLink {
            AthkarSearchMushafPage(page: ayah.page, ayah: ayah)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        // RTL: the gold title sits at the right, gray meta after.
                        let surah = QuranDatabase.shared.surah(ayah.surahID)
                        if let surah {
                            Text(surah.name)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(athkarHomeGold)
                            Text(settings.t("آية \(ayah.number)", "Ayah \(ayah.number)"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    Text(ayah.text)
                        .font(.custom("KFGQPCHAFSUthmanicScript-Bold", size: 19))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 6)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AthkarResultGroup: View {
    @EnvironmentObject private var settings: SettingsStore
    let category: AthkarCategory
    let entries: [AthkarEntry]

    var body: some View {
        VStack(spacing: 0) {
            Text(category.localizedTitle(settings.lang))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(athkarHomeGold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
            ForEach(entries, id: \.id) { entry in
                NavigationLink {
                    AthkarPageView(category: category)
                } label: {
                    AthkarResultRow(category: category, entry: entry)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
        }
    }
}

/// One athkar match: gold title (entry's own title or the first words of the
/// text), the full entry below in Scheherazade, left chevron.
private struct AthkarResultRow: View {
    let category: AthkarCategory
    let entry: AthkarEntry

    private var title: String {
        entry.Title ?? String(AthkarStore.stripHTML(entry.Athkar ?? "").prefix(32))
    }

    private var snippet: String {
        AthkarStore.stripHTML(entry.Athkar ?? "")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(athkarHomeGold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(snippet)
                    .font(.athkarBody)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top, 6)
        }
    }
}

/// Deep link into the 604-page mushaf at one matched ayah's printed page:
/// the page number is persisted to the same `quranLastPage` key the mushaf
/// restores from, so the pushed QuranPagesView opens exactly there, and the
/// matched ayah itself gets the one-shot olive-gold `.jump` highlight
/// (QuranJumpTarget is set here, taken/cleared by the pages view on appear).
private struct AthkarSearchMushafPage: View {
    let page: Int

    init(page: Int, ayah: QuranAyah) {
        self.page = page
        QuranPagesTracker.save(page)
        QuranJumpTarget.set(surah: ayah.surahID, ayah: ayah.number)
    }

    var body: some View {
        QuranPagesView()
    }
}

/// (Legacy: the flat المزيد list. Superseded by AthkarMoreGridPage, the
/// capture-verified two-column tinted card grid; kept for reference.)
struct AthkarSectionsListView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var categories: [AthkarCategory] = []

    var body: some View {
        List {
            Section {
                NavigationLink(value: "khatmah") {
                    Label(settings.t("ورد الختمة", "Khatmah Portion"), systemImage: "checkmark.seal.fill")
                }
                NavigationLink(value: "myAthkar") {
                    Label(settings.t("أذكاري", "My Athkar"), systemImage: "text.badge.plus")
                }
                NavigationLink(value: "allahNames") {
                    Label(settings.t("أسماء الله الحسنى", "Names of Allah"), systemImage: "star.circle.fill")
                }
            }
            Section {
                ForEach(categories) { category in
                    NavigationLink(value: category) {
                        HStack {
                            Text(category.localizedTitle(settings.lang))
                            Spacer()
                            Text("\(category.entries.count)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(settings.t("المزيد", "More"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if categories.isEmpty { categories = AthkarStore.loadCategories() }
        }
    }
}

/// Category detail pushed from home / favorites / search. The full single-
/// zikr + card-list implementation (live-capture rebuild) lives in
/// AthkarPageDetailView.swift; this wrapper keeps every `AthkarPageView`
/// entry point valid.
struct AthkarPageView: View {
    let category: AthkarCategory

    var body: some View {
        AthkarPageDetailView(category: category)
    }
}
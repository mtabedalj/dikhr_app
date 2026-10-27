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
// Live capture ground truth (/tmp/athkar_live_1.png):
//   chips: المنوعة / الصلاة / القبلة / المفضلة / العداد (Vision OCR of the live app)
//   banner verse: "وَعَلَىٰ رَبِّهِمْ يَتَوَكَّلُونَ"
//   strip: العشاء 07:52 right, الفجر 06:42 left, hijri medallion center
//   countdown row gold: "الفجر بعد 6:54:09" (next prayer, live HH:MM:SS)
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
                case "favorites": AthkarFavoritesView()
                case "search": AthkarSearchView()
                case "more": AthkarSectionsListView()
                default: AthkarSearchView()
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
        }
    }

    private func refreshRing() {
        let day = StreaksStore.today()
        let done = [day.prayers, day.quran, day.nawafil, day.athkarCount > 0].filter { $0 }.count
        ringRatio = Double(done) / 4.0
    }

    // MARK: 1. night-sky header

    private var skyHeader: some View {
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
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Spacer()
                    homeCircleButton("gearshape.fill", action: {
                        DeepLinkRouter.shared.pendingTab = "settings"
                    })
                    homeCircleButton("magnifyingglass", action: { path.append("search") })
                    homeCircleButton("bookmark", action: { path.append("favorites") })
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)
                Spacer()
                Text("وَعَلَىٰ رَبِّهِمْ يَتَوَكَّلُونَ")
                    .font(.custom("KFGQPCHAFSUthmanicScript-Bold", size: 30))
                    .foregroundStyle(Color(red: 0.97, green: 0.95, blue: 0.90))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }
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
                // RTL: first child leads on the right — عشاء right, فجر left (like the capture)
                if let times = prayerTimes {
                    stripTime(settings.t(PrayerKind.isha.arabicName, PrayerKind.isha.englishName),
                              hhColonMM(times.isha))
                    Spacer()
                    medallion
                    Spacer()
                    stripTime(settings.t(PrayerKind.fajr.arabicName, PrayerKind.fajr.englishName),
                              hhColonMM(times.fajr))
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
                        DeepLinkRouter.shared.pendingTab = "counter"
                    case .all, .prayer:
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

    // MARK: 4. gold countdown row

    private var countdownRow: some View {
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

    private var nextPrayer: (kind: PrayerKind, date: Date)? {
        guard let method = HomeCards.resolveMethod(settings: settings) else { return nil }
        func upcoming(on date: Date) -> (kind: PrayerKind, date: Date)? {
            let t = PrayerTimesEngine.calculate(
                method: method, lat: settings.currentCity.lat, lng: settings.currentCity.lng,
                date: date, timeZone: .current)
            // Prayers only (sunrise excluded): matches the capture's "الفجر بعد".
            let events: [(PrayerKind, Date)] = [
                (.fajr, t.fajr), (.dhuhr, t.dhuhr), (.asr, t.asr),
                (.maghrib, t.maghrib), (.isha, t.isha)]
            return events.first { $0.1 > now }
        }
        return upcoming(on: now)
            ?? upcoming(on: Calendar.current.date(byAdding: .day, value: 1,
                                                  to: Calendar.current.startOfDay(for: now)) ?? now)
    }

    private func hms(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
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
            return ["allahNames", "Page1", "Page2", "Tasbee7", "Page5", "myAthkar",
                    "Page31", "Page3", "Page7", "Page8", "RoqiaQuran", "RoqiaSuna",
                    "AkherAyateen", "Page4", "Page6", "more"]
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
        }
        .overlay {
            if favoriteGroups.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "star")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(settings.t("لا يوجد دعاء في المفضلة. لإضافة دعاء هنا اذهب إلى صفحة الأذكار واضغط على زر النجمة.",
                                    "No favorites yet. Open an athkar page and tap the star to add one."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
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

/// البحث — search athkar sections and entry text.
struct AthkarSearchView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var query = ""
    @State private var categories: [AthkarCategory] = []

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                Section(settings.t("الأقسام", "Sections")) {
                    ForEach(categories) { category in
                        NavigationLink(value: category) {
                            Text(category.localizedTitle(settings.lang))
                        }
                    }
                }
            } else {
                ForEach(matching, id: \.category.id) { group in
                    Section(group.category.localizedTitle(settings.lang)) {
                        ForEach(group.entries, id: \.id) { entry in
                            NavigationLink {
                                AthkarPageView(category: group.category)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.Title ?? "")
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(AthkarStore.stripHTML(entry.Athkar ?? ""))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(settings.t("البحث", "Search"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(settings.t("ابحث في الأذكار", "Search athkar")))
        .onAppear {
            if categories.isEmpty { categories = AthkarStore.loadCategories() }
        }
    }

    private struct Group {
        let category: AthkarCategory
        let entries: [AthkarEntry]
    }

    private var matching: [Group] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }
        return categories.map { category in
            Group(category: category,
                  entries: category.entries.filter {
                      AthkarStore.stripHTML($0.Athkar ?? "").contains(needle)
                      || ($0.Title ?? "").contains(needle)
                  })
        }
        .filter { !$0.entries.isEmpty }
    }
}

/// المزيد — one flat list of every athkar route + section.
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

struct AthkarPageView: View {
    let category: AthkarCategory
    @EnvironmentObject private var settings: SettingsStore
    @State private var counted: [Int: Int] = [:]
    @State private var listening = false

    private func countDhikr() {
        StreaksStore.addAthkar(1)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(Array(category.entries.enumerated()), id: \.offset) { index, entry in
                        AthkarCard(entry: entry, timesCounted: counted[index] ?? 0,
                                   isFavorite: settings.favorites.contains(favoriteID(category, entry)),
                                   onIncrement: {
                                       counted[index, default: 0] += 1
                                       countDhikr()
                                   },
                                   onFavorite: { toggleFavorite(category, entry) },
                                   onPlay: { listening = true })
                            .id(index)
                    }
                }
                .padding()
            }
            .navigationTitle(category.localizedTitle(settings.lang))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $listening) {
                AthkarListeningView(category: category)
            }
            .onAppear {
                if ProcessInfo.processInfo.environment["DIKHTML_LISTEN"] != nil ||
                   ProcessInfo.processInfo.environment["DIKHR_LISTEN"] != nil {
                    listening = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AthkarListeningView(category: category)
                    } label: {
                        Image(systemName: "headphones")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Text(settings.t("التكرار: \(counted.values.reduce(0, +))",
                                        "Repeats: \(counted.values.reduce(0, +))"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(action: {
                            let next = (counted.keys.max() ?? -1) + 1
                            if next < category.entries.count {
                                withAnimation { proxy.scrollTo(next, anchor: .center) }
                            }
                        }, label: {
                            Image(systemName: "arrow.down.circle")
                        })
                    }
                }
            }
        }
    }

    private func favoriteID(_ category: AthkarCategory, _ entry: AthkarEntry) -> String {
        let fallback = String(AthkarStore.stripHTML(entry.Athkar ?? "").prefix(24))
        return "\(category.id)|\(entry.Title ?? fallback)"
    }

    private func toggleFavorite(_ category: AthkarCategory, _ entry: AthkarEntry) {
        let id = favoriteID(category, entry)
        if settings.favorites.contains(id) {
            settings.favorites.remove(id)
        } else {
            settings.favorites.insert(id)
        }
    }
}

struct AthkarCard: View {
    @EnvironmentObject private var settings: SettingsStore
    let entry: AthkarEntry
    let timesCounted: Int
    let isFavorite: Bool
    let onIncrement: () -> Void
    let onFavorite: () -> Void
    var onPlay: (() -> Void)? = nil

    private var requiredCount: Int { max(1, entry.Count ?? 1) }
    private var segments: [AthkarTextRenderer.Segment] { AthkarTextRenderer.segments(entry.Athkar ?? "") }
    private var done: Bool { timesCounted >= requiredCount }

    private var buttonLabel: String {
        if done { return settings.t("تم", "Done") }
        if timesCounted == 0 {
            return requiredCount > 1
                ? settings.t("تكرار \(requiredCount)", "Repeat \(requiredCount)")
                : settings.t("عدِّد", "Count")
        }
        return "\(timesCounted)/\(requiredCount)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.Title ?? "")
                    .font(.headline)
                    .foregroundStyle(.accent)
                Spacer()
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(segments) { segment in
                    Text(segment.text)
                        .font(AthkarTextRenderer.font(segment.style))
                        .foregroundStyle(AthkarTextRenderer.foregroundColor(segment.style))
                        .lineSpacing(AthkarTextRenderer.lineSpacing(segment.style))
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(segment.style == .attribution ? .center : .leading)
                }
            }

            HStack {
                if let onPlay, entry.Audio.map({ !$0.isEmpty }) == true {
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.accent)
                    }
                    .buttonStyle(.borderless)
                }
                if requiredCount > 1 {
                    Text(settings.t("تكرار: \(requiredCount)", "Repeat: \(requiredCount)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onIncrement) {
                    Label(buttonLabel,
                          systemImage: done ? "checkmark.circle.fill" : "hand.tap")
                        .font(.callout.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(done ? .green : .accent)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
        .opacity(done ? 0.75 : 1)
    }
}
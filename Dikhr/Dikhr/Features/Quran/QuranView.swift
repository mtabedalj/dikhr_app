import SwiftUI
import SQLite3

// MARK: - المصحف — Quran tab root, rebuilt from live capture /tmp/ath_quran.png
//
// The real Athkar app's المصحف page: near-black page; bold white "المصحف"
// beside a round ">" back chevron at the far edge; three round chrome buttons
// top-opposite (gear → settings sheet, share, search). Under it a 2x2 card
// block: two dark stat cards (right: "آخر آية · النساء 139 · ص 100" over a
// "اليوم · 6:00 م" read stamp; left: "آخر صفحة · النساء 101" over its own
// stamp; both collapse to "—" before any reading) then two action cards
// (right: ختمة → KhatmahView; left: استمع سورة الفاتحة with a round play).
// Four filter chips switch the body grid:
//   السور    → 3-column surah tiles: Uthmanic Basmala opener on top (the
//              capture shows the same بسم الله glyph on every tile; Tawbah —
//              the basmala-less surah — falls back to its first verse's own
//              words), a number badge + mini play on the tile's edge and gray
//              meta rows "مكية ،آياتها : N" / "الصفحة N"; tap pushes the
//              surah, the mini play streams its first ayah.
//   الأجزاء  → 30 juz tiles with printed-page ranges → mushaf page.
//   الأحزاب  → 60 hizb tiles (Quran.sqlite's hizb table: start page of the
//              start ayah, end page = next hizb's start − 1).
//   الصفحات  → 604 numbered page tiles → QuranPagesView(startPage:).
// Tile mini-plays and the استمع button share VerseAudioPlayer (VerseModal's
// everyayah streaming, playing a surah's first ayah), like the original's
// "استمع" resume-from-last-position card.
// Dark chrome + RTL direction are forced like the other parity pages.

private let quranTabGold = Color(red: 0.79, green: 0.65, blue: 0.35)

struct QuranView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var surahs: [QuranSurah] = []
    @State private var tawbahOpener = ""
    @State private var chip: Chip = .surahs
    @State private var path: [QuranSurah] = []
    @State private var showSearch = false
    @State private var showSettings = false
    @StateObject private var audio = VerseAudioPlayer.shared
    @StateObject private var pageStore = QuranPageStore()
    @StateObject private var hizbStore = QuranHizbStore()

    enum Chip: CaseIterable, Identifiable {
        case surahs, ajza, ahzab, pages
        var id: Self { self }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    statCards
                    actionCards
                    chipBar
                    chipContent
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: QuranSurah.self) { surah in
                QuranSurahView(surah: surah)
            }
            .navigationDestination(for: QuranPageTarget.self) { target in
                QuranPagesView(startPage: target.page)
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView()
            }
            .sheet(isPresented: $showSearch) {
                QuranSearchSheet(surahs: surahs) { surah in path = [surah] }
            }
            .preferredColorScheme(.dark)
            .onAppear { load() }
        }
    }

    // MARK: chrome (title + ">" back far edge; gear / share / search opposite)

    private var topBar: some View {
        HStack(spacing: 12) {
            // Back: pops any pushed detail pages (the tab's own stack root
            // itself has nothing to pop, like the original's stack top).
            Button { path = [] } label: { chromeCircle("chevron.forward") }
            Text(settings.t("المصحف", "Mushaf"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button { showSettings = true } label: { chromeCircle("gearshape") }
            ShareLink(item: shareText) { chromeCircle("square.and.arrow.down") }
            Button { showSearch = true } label: { chromeCircle("magnifyingglass") }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private func chromeCircle(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.white.opacity(0.10)))
            .contentShape(Circle())
    }

    // MARK: stat cards (last verse — right; last mushaf page — left)

    private var statCards: some View {
        HStack(alignment: .top, spacing: 12) {
            verseStatCard
            pageStatCard
        }
        .padding(.horizontal, 16)
    }

    private var verseStatCard: some View {
        statCard(line: verseStatLine, stamp: verseStatStamp)
    }

    private var pageStatCard: some View {
        statCard(line: pageStatLine, stamp: pageStatStamp)
    }

    private func statCard(line: String, stamp: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(line)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Text(stamp)
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.055))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.10))))
    }

    /// "آخر آية · النساء 139 · ص 100" — Dikhr's recorded last-read verse; if
    /// none yet, approximated from the last-read page's first ayah.
    private var verseStatLine: String {
        if let lastRead = QuranBookmarkStore.lastRead() {
            let name = surahs.first(where: { $0.id == lastRead.surah })?.name ?? ""
            if let page = QuranDatabase.shared.ayahIDs(surahID: lastRead.surah,
                                                       number: lastRead.ayah)?.page {
                return settings.t("آخر آية", "Last verse") + " · \(name) \(lastRead.ayah) · ص \(page)"
            }
        }
        if let page = QuranPagesTracker.storedPage(),
           let first = pageStore.page(page).ayahs.first {
            let name = surahs.first(where: { $0.id == first.surahID })?.name ?? ""
            return settings.t("آخر آية", "Last verse") + " · \(name) \(first.number) · ص \(page)"
        }
        return settings.t("آخر آية", "Last verse") + " · —"
    }

    private var verseStatStamp: String {
        if let date = QuranBookmarkStore.lastReadDate() { return stamp(date) }
        if let date = QuranPagesTracker.lastReadDate() { return stamp(date) }
        return "—"
    }

    /// "آخر صفحة · النساء 101" — QuranPagesTracker's last-read mushaf page,
    /// labeled with the surah printed on that page (pages table).
    private var pageStatLine: String {
        if let page = QuranPagesTracker.storedPage() {
            let name = pageStore.page(page).surahNames
            if !name.isEmpty {
                return settings.t("آخر صفحة", "Last page") + " · \(name) \(page)"
            }
            return settings.t("آخر صفحة", "Last page") + " · \(page)"
        }
        return settings.t("آخر صفحة", "Last page") + " · —"
    }

    private var pageStatStamp: String {
        QuranPagesTracker.lastReadDate().map(stamp) ?? "—"
    }

    // MARK: action cards (ختمة — right; استمع — left)

    private var actionCards: some View {
        HStack(spacing: 12) {
            khatmahCard
            listenCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var khatmahCard: some View {
        NavigationLink {
            KhatmahView()
        } label: {
            ZStack {
                Text(settings.t("ختمة", "Khatmah"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                HStack {
                    Image(systemName: "text.book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(quranTabGold)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.12)))
        }
        .buttonStyle(.plain)
    }

    private var listenCard: some View {
        HStack(spacing: 10) {
            if let surah = listenSurah {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.t("استمع", "Listen"))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                    Text(settings.t("سورة \(surah.name)", "Surah \(surah.name)"))
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.55))
                }
                Spacer()
                Button {
                    if let ayah = firstAyah(of: surah) {
                        audio.togglePlay(aayah: ayah)
                    }
                } label: {
                    Image(systemName: isListenPlaying(surah) ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.105)))
    }

    /// The استمع target: the last-read surah, or سورة الفاتحة (as captured).
    private var listenSurah: QuranSurah? {
        let id = QuranBookmarkStore.lastRead()?.surah ?? 1
        return surahs.first(where: { $0.id == id }) ?? surahs.first
    }

    private func isListenPlaying(_ surah: QuranSurah) -> Bool {
        if case (surah.id, 1)? = audio.currentlyPlaying, audio.isPlaying { return true }
        return false
    }

    /// Lightweight stand-in ayah for playback (VerseAudioPlayer only uses
    /// surah + ayah number; text stays empty so no DB read is wasted).
    private func firstAyah(of surah: QuranSurah) -> QuranAyah? {
        guard let ids = QuranDatabase.shared.ayahIDs(surahID: surah.id, number: 1) else {
            return nil
        }
        return QuranAyah(id: ids.id, surahID: surah.id, number: 1, text: "", page: ids.page)
    }

    // MARK: filter chips (السور / الأجزاء / الأحزاب / الصفحات)

    private var chipBar: some View {
        HStack(spacing: 10) {
            ForEach(Chip.allCases) { candidate in
                Button { chip = candidate } label: {
                    Text(chipLabel(candidate))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Capsule().fill(
                            chip == candidate ? Color.white.opacity(0.20)
                                              : Color.white.opacity(0.055)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private func chipLabel(_ chip: Chip) -> String {
        switch chip {
        case .surahs: return settings.t("السور", "Surahs")
        case .ajza: return settings.t("الأجزاء", "Juz")
        case .ahzab: return settings.t("الأحزاب", "Hizb")
        case .pages: return settings.t("الصفحات", "Pages")
        }
    }

    @ViewBuilder
    private var chipContent: some View {
        ScrollView {
            switch chip {
            case .surahs: surahGrid
            case .ajza: juzGrid
            case .ahzab: hizbGrid
            case .pages: pagesGrid
            }
        }
    }

    private var threeColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    }

    // MARK: السور grid

    private var surahGrid: some View {
        LazyVGrid(columns: threeColumns, spacing: 14) {
            ForEach(surahs) { surah in
                surahTile(surah)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 40)
    }

    private func surahTile(_ surah: QuranSurah) -> some View {
        NavigationLink(value: surah) {
            HStack(spacing: 4) {
                VStack(spacing: 14) {   // badge column rides the near edge
                    Text("\(surah.id)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 9)
                            .fill(Color.white.opacity(0.12)))
                    Button {
                        if let ayah = firstAyah(of: surah) {
                            audio.togglePlay(aayah: ayah)
                        }
                    } label: {
                        Image(systemName: isListenPlaying(surah)
                              ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 9)
                                .fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
                VStack(spacing: 6) {
                    Text(opener(for: surah))
                        .font(.quranUthmani)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .frame(maxWidth: .infinity)
                    Text("\(surah.revelationType) ،آياتها : \(surah.ayahCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(white: 0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(settings.t("الصفحة \(surah.page)", "Page \(surah.page)"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(white: 0.55))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(12)
            .frame(height: 152)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.105)))
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    /// Every tile opens with the Basmala per the capture; Tawbah (no
    /// basmala in mushaf) shows its first verse's own opening words.
    private func opener(for surah: QuranSurah) -> String {
        if surah.id == 9, !tawbahOpener.isEmpty { return tawbahOpener }
        return "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ"
    }

    // MARK: الأجزاء grid

    private var juzGrid: some View {
        LazyVGrid(columns: threeColumns, spacing: 14) {
            ForEach(pageStore.juzSections()) { section in
                let pages = section.rows.map(\.page)
                NavigationLink(value: QuranPageTarget(page: pages.first ?? 1)) {
                    collectionTile(title: section.name, range: pages)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 40)
    }

    // MARK: الأحزاب grid

    private var hizbGrid: some View {
        LazyVGrid(columns: threeColumns, spacing: 14) {
            ForEach(hizbStore.items) { hizb in
                NavigationLink(value: QuranPageTarget(page: hizb.startPage)) {
                    collectionTile(title: settings.t("الحزب \(hizb.hizb)",
                                                     "Hizb \(hizb.hizb)"),
                                   range: [hizb.startPage, hizb.endPage])
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 40)
    }

    private func collectionTile(title: String, range: [Int]) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if range.count >= 2 {
                Text(settings.t("الصفحات \(range[0]) – \(range[1])",
                                "Pages \(range[0]) – \(range[1])"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.105)))
    }

    // MARK: الصفحات grid

    private var pagesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                 count: 4),
                  spacing: 10) {
            ForEach(1...604, id: \.self) { page in
                NavigationLink(value: QuranPageTarget(page: page)) {
                    Text("\(page)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.105)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 40)
    }

    // MARK: data + stamps

    private func load() {
        if surahs.isEmpty { surahs = QuranDatabase.shared.surahs() }
        hizbStore.loadIfNeeded()
        if tawbahOpener.isEmpty,
           let first = QuranDatabase.shared.ayahs(surahID: 9).first {
            tawbahOpener = first.text.split(separator: " ")
                .prefix(7).joined(separator: " ")
        }
        if let push = ProcessInfo.processInfo.environment["DIKHR_SURAH"],
           let id = Int(push), let surah = surahs.first(where: { $0.id == id }) {
            path = [surah]
        }
    }

    /// "اليوم · 6:00 م" — the captured stamp row (yesterday and date fallbacks).
    private func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let meridiem = Calendar.current.component(.hour, from: date) < 12 ? " ص" : " م"
        let time = formatter.string(from: date) + meridiem
        if Calendar.current.isDateInToday(date) {
            return settings.t("اليوم", "Today") + " · \(time)"
        }
        if Calendar.current.isDateInYesterday(date) {
            return settings.t("أمس", "Yesterday") + " · \(time)"
        }
        let day = DateFormatter()
        day.dateFormat = "d/M"
        return day.string(from: date) + " · \(time)"
    }

    /// ShareLink of the reading position (honest mapping of the original's
    /// download/share chrome button).
    private var shareText: String {
        let position: String
        if let page = QuranPagesTracker.storedPage() {
            let name = pageStore.page(page).surahNames
            position = name.isEmpty
                ? settings.t("صفحة \(page)", "Page \(page)")
                : "\(name) · \(settings.t("صفحة \(page)", "Page \(page)"))"
        } else {
            position = settings.t("المصحف", "Mushaf")
        }
        return settings.t("آخر قراءة بالمسحف —", "Last reading —") + " " + position
    }
}

/// Push target for mushaf pages chosen from the الأجزاء / الأحزاب / الصفحات
/// chips (Int is already the QuranSurah navigation value's payload shape).
struct QuranPageTarget: Hashable {
    let page: Int
}

// MARK: - Hizb quarters (Quran.sqlite's `hizb` table — Data/ stays untouched)

/// 60 hizb tiles: start page via the start ayah's printed page, end page =
/// the next hizb's start − 1 (the last hizb runs to 604). Own read-only
/// connection, loaded once.
final class QuranHizbStore: ObservableObject {
    struct HizbInfo: Identifiable {
        let hizb: Int
        let startPage: Int
        let endPage: Int
        var id: Int { hizb }
    }

    private(set) var items: [HizbInfo] = []

    func loadIfNeeded() {
        guard items.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: "Quran", withExtension: "sqlite") else {
            return
        }
        var pointer: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &pointer, flags, nil) == SQLITE_OK,
              let db = pointer else { return }
        defer { sqlite3_close_v2(db) }
        var statement: OpaquePointer?
        let sql = """
            SELECT h.hizb, a.page FROM hizb h
            JOIN ayah a ON a.surah_id = h.sura_start AND a.number = h.aya_start
            ORDER BY h.hizb
            """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        var starts: [(hizb: Int, page: Int)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            starts.append((Int(sqlite3_column_int64(statement, 0)),
                           Int(sqlite3_column_int64(statement, 1))))
        }
        items = starts.enumerated().map { index, row in
            let end = index + 1 < starts.count ? starts[index + 1].page - 1 : 604
            return HizbInfo(hizb: row.hizb, startPage: row.page,
                            endPage: max(row.page, end))
        }
    }
}

// MARK: - In-tab Quran search (kept as a sheet from the search chrome button)

/// The previous Quran tab's search list, preserved: type to filter Quran text,
/// tap a result to push its surah (the sheet dismisses first).
struct QuranSearchSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    let surahs: [QuranSurah]
    let onPick: (QuranSurah) -> Void
    @State private var query = ""
    @State private var results: [QuranAyah] = []

    var body: some View {
        NavigationStack {
            List {
                if !query.isEmpty && results.isEmpty {
                    Text(settings.t("لا توجد نتائج", "No results"))
                        .foregroundStyle(.secondary)
                }
                ForEach(results) { ayah in
                    Button {
                        if let surah = surahs.first(where: { $0.id == ayah.surahID }) {
                            dismiss()
                            onPick(surah)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ayah.text)
                                .font(.system(size: 19, design: .serif))
                                .foregroundStyle(.primary)
                                .lineSpacing(8)
                            Text(label(for: ayah))
                                .font(.caption2)
                                .foregroundStyle(.tint)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $query, prompt: settings.t("ابحث في القرآن", "Search the Quran"))
            .navigationTitle(settings.t("البحث في المصحف", "Search the Quran"))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: query) { _, newQuery in
                results = newQuery.count > 1 ? QuranDatabase.shared.search(newQuery) : []
            }
        }
        .preferredColorScheme(.dark)
    }

    private func label(for ayah: QuranAyah) -> String {
        if let surah = surahs.first(where: { $0.id == ayah.surahID }) {
            return settings.t("\(surah.name) \u{2022} آية \(ayah.number)",
                              "\(surah.name) \u{2022} ayah \(ayah.number)")
        }
        return ""
    }
}

struct QuranSurahView: View {
    @EnvironmentObject private var settings: SettingsStore
    let surah: QuranSurah
    @State private var ayahs: [QuranAyah] = []
    @State private var mushafMode = true

    var body: some View {
        Group {
            if mushafMode {
                MushafHTMLView(surah: surah, ayahs: ayahs, bookmarkedAyahs: bookmarkedKeys())
                    .ignoresSafeArea(edges: .bottom)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        LazyVStack(spacing: 10) {
                            ForEach(ayahs) { ayah in
                                AyahRow(ayah: ayah, surah: surah)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 40)
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(surah.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mushafMode.toggle()
                } label: {
                    Image(systemName: mushafMode ? "list.bullet.rectangle" : "text.book.closed")
                }
            }
        }
        .onAppear {
            guard ayahs.isEmpty else { return }
            ayahs = QuranDatabase.shared.ayahs(surahID: surah.id)
            StreaksStore.setQuran(true)
        }
    }

    /// "surah:ayah" keys of this surah's bookmarks — drives the mushaf
    /// `<mark>`-style yellow highlight (the original's `.highlight`).
    private func bookmarkedKeys() -> Set<String> {
        Set(QuranBookmarkStore.bookmarks()
            .filter { $0.surah == surah.id }
            .map { "\($0.surah):\($0.ayah)" })
    }

    private var mushafHeader: some View {
        VStack(spacing: 10) {
            if ![1, 9].contains(surah.id) {
                Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
                    .font(.quranUthmani)
                    .foregroundStyle(QuranPalette.darkGreen)
            }
            Image(systemName: "seal.fill")
                .font(.title3)
                .foregroundStyle(QuranPalette.darkGreen)
            Text(surah.name)
                .font(.title2.bold())
                .foregroundStyle(QuranPalette.darkGreen)
            HStack(spacing: 10) {
                hairline
                Text(settings.t("\(surah.revelationType) \u{2022} \(surah.ayahCount) آية",
                                "\(surah.revelationType) \u{2022} \(surah.ayahCount) ayahs"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                hairline
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var hairline: some View {
        Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 44, height: 1)
    }

    /// Each ayah as its own paragraph with a drawn medallion; short Texts shape
    /// correctly (a single long Text with annotation signs garbles in SwiftUI).
    private func arabicDigits(_ n: Int) -> String {
        let arabic = ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"]
        return String(n).map { $0.isNumber ? arabic[Int(String($0)) ?? 0] ?? "" : String($0) }.joined()
    }
}

struct AyahRow: View {
    @EnvironmentObject private var settings: SettingsStore
    let ayah: QuranAyah
    let surah: QuranSurah
    @State private var isBookmarked = false
    @State private var showTafseer = false
    @State private var showVerseModal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Verse text: tap opens the VerseModal (play / tafseer / bookmark);
            // a bookmark paints the original's `.highlight` yellow background.
            Text(ayah.text)
                .font(.quranUthmani)
                .lineSpacing(14)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .background(isBookmarked ? Color.yellow.opacity(0.85) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { showVerseModal = true }
            if showTafseer, let taf = TafseerDatabase.shared.tafseer(surah: ayah.surahID, ayah: ayah.number) {
                Divider()
                Text(settings.t("التفسير الميسر", "Clear Tafsir"))
                    .font(.footnote.bold())
                    .foregroundStyle(.accent)
                Text(taf)
                    .font(.callout)
                    .lineSpacing(8)
                    .foregroundStyle(.secondary)
            }


            HStack {
                Text(settings.t("آية \(ayah.number) \u{2022} \(surah.name)",
                                "Ayah \(ayah.number) \u{2022} \(surah.name)"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    if isBookmarked {
                        QuranBookmarkStore.remove(surahID: ayah.surahID, ayah: ayah.number)
                    } else {
                        QuranBookmarkStore.add(surahID: ayah.surahID, ayah: ayah.number)
                    }
                    isBookmarked = QuranBookmarkStore.isBookmarked(surahID: ayah.surahID, ayah: ayah.number)
                    QuranBookmarkStore.recordLastRead(surahID: ayah.surahID, ayah: ayah.number)
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isBookmarked ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)
                Button { showTafseer.toggle() } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .sheet(isPresented: $showVerseModal) {
            VerseModal(aayah: ayah, surah: surah, bookmarked: $isBookmarked)
        }
        .onAppear {
            isBookmarked = QuranBookmarkStore.isBookmarked(surahID: ayah.surahID, ayah: ayah.number)
            QuranBookmarkStore.recordLastRead(surahID: ayah.surahID, ayah: ayah.number)
        }
    }
}

enum QuranBookmarkStore {
    struct Bookmark: Codable, Identifiable, Hashable {
        var surah: Int
        var ayah: Int
        var surahName: String
        var id: String { "\(surah):\(ayah)" }
    }

    static func isBookmarked(surahID: Int, ayah: Int) -> Bool {
        bookmarks().contains(where: { $0.surah == surahID && $0.ayah == ayah })
    }
    static func add(surahID: Int, ayah: Int) {
        var list = bookmarks()
        list.append(Bookmark(surah: surahID, ayah: ayah,
                             surahName: QuranDatabase.shared.surah(surahID)?.name ?? ""))
        persist(list)
    }
    static func remove(surahID: Int, ayah: Int) {
        persist(bookmarks().filter { !($0.surah == surahID && $0.ayah == ayah) })
    }
    static func bookmarks() -> [Bookmark] {
        guard let data = UserDefaults.standard.data(forKey: "quranBookmarks"),
              let list = try? JSONDecoder().decode([Bookmark].self, from: data)
        else { return [] }
        return list
    }
    static func recordLastRead(surahID: Int, ayah: Int) {
        UserDefaults.standard.set(
            ["surah": surahID, "ayah": ayah, "date": Date()],
            forKey: "quranLastRead")
    }
    /// When the verse was last read (nil for pre-stamp entries — the المصحف
    /// stat card shows "—" then).
    static func lastReadDate() -> Date? {
        (UserDefaults.standard.dictionary(forKey: "quranLastRead")?["date"]) as? Date
    }
    static func lastRead() -> (surah: Int, ayah: Int)? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "quranLastRead"),
              let surah = dict["surah"] as? Int, let ayah = dict["ayah"] as? Int
        else { return nil }
        return (surah, ayah)
    }
    private static func persist(_ list: [Bookmark]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "quranBookmarks")
        }
    }
}
import SwiftUI
import SQLite3

/// المصحف المطبوع — the printed mushaf pages mode: the 604 printed pages of
/// Quran.sqlite's `ayah` table (`page` column), each rendered as one justified
/// block, swiped through page by page like a real mushaf (RTL).
struct QuranPagesView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var store = QuranPageStore()
    @State private var page: Int
    @State private var surahs: [QuranSurah] = []
    @State private var showPageList = false
    @State private var showSurahList = false
    /// The one-shot search jump target for this appearance; cleared once the
    /// user turns the page so a later swipe back renders without the highlight.
    @State private var jumpTarget: QuranJumpTarget.Point?
    @State private var appearedPage: Int = 0

    init(startPage: Int? = nil) {
        // Khatmah: restore the last-read page on open; the المصحف chips'
        // (الأجزاء / الأحزاب / الصفحات) tiles open at a chosen page instead.
        _page = State(initialValue: startPage ?? QuranPagesTracker.restore())
    }

    var body: some View {
        VStack(spacing: 0) {
            pageBar
            Divider().overlay(QuranPalette.darkGreen.opacity(0.18))
            TabView(selection: Binding(get: { page }, set: { page = $0 })) {
                ForEach(1...604, id: \.self) { number in
                    QuranPageCell(page: number, selection: page, store: store, jumpTarget: jumpTarget)
                        .tag(number)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // RTL paging: swiping flips pages like turning a real mushaf.
            .environment(\.layoutDirection, .rightToLeft)
        }
        .background(QuranPalette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showPageList = true
                    } label: {
                        Label(settings.t("قائمة الصفحات", "Page List"), systemImage: "list.number")
                    }
                    Button {
                        showSurahList = true
                    } label: {
                        Label(settings.t("السور", "Surahs"), systemImage: "book.closed")
                    }
                } label: {
                    Image(systemName: "square.grid.3x3")
                        .foregroundStyle(QuranPalette.darkGreen)
                }
            }
        }
        .sheet(isPresented: $showPageList) {
            QuranPageListSheet(store: store, current: page) { page = $0 }
        }
        .sheet(isPresented: $showSurahList) {
            QuranSurahJumpSheet(surahs: surahs) { page = $0 }
        }
        .onChange(of: page) { _, newPage in
            QuranPagesTracker.save(newPage)
            // First paint done: turning the page drops the one-shot jump highlight.
            if jumpTarget != nil && newPage != appearedPage {
                jumpTarget = nil
            }
        }
        .onAppear {
            if surahs.isEmpty { surahs = QuranDatabase.shared.surahs() }
            QuranPagesTracker.save(page)
            StreaksStore.setQuran(true)
            if let jump = ProcessInfo.processInfo.environment["DIKHR_PAGE"],
               let n = Int(jump), (1...604).contains(n) {
                page = n
            }
            // Consume the athkar-search jump exactly once per appearance.
            if jumpTarget == nil {
                jumpTarget = QuranJumpTarget.take()
            }
            appearedPage = page
        }
    }

    // MARK: - Page navigation bar

    private var pageBar: some View {
        HStack(spacing: 12) {
            // Juz indicator (leading = right in RTL, like the mushaf band).
            HStack(spacing: 4) {
                Text("❁")
                Text(juzTitle)
                    .font(.caption.bold())
            }
            .foregroundStyle(QuranPalette.darkGreen)

            Spacer()

            Button {
                showPageList = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.number")
                    Text(settings.t("صفحة \(QuranPageHTML.arabicDigits(page))",
                                    "Page \(QuranPageHTML.arabicDigits(page))"))
                        .font(.headline)
                }
                .foregroundStyle(QuranPalette.darkGreen)
            }
            .accessibilityLabel(settings.t("الانتقال إلى صفحة", "Go to page"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(QuranPalette.paper)
    }

    private var juzTitle: String {
        DikhrStrings.tr("الجزء \(QuranPageHTML.arabicDigits(store.page(page).juzID))",
                        "Juz \(store.page(page).juzID)")
    }
}

/// Only the visible page (and its flip neighbours) load a WKWebView; distant
/// pages stay as a light paper placeholder so the 604-page TabView stays cheap.
struct QuranPageCell: View {
    @EnvironmentObject private var settings: SettingsStore
    let page: Int
    let selection: Int
    let store: QuranPageStore
    /// One-shot search jump (surah+ayah) for this appearance, or nil. Only the
    /// page actually holding that ayah renders the olive-gold highlight.
    var jumpTarget: QuranJumpTarget.Point?

    /// "surah:ayah" bookmark keys on this page — drives the yellow highlight.
    private func bookmarkedKeys(_ ayahs: [QuranAyah]) -> Set<String> {
        let bookmarked = Set(QuranBookmarkStore.bookmarks().map { "\($0.surah):\($0.ayah)" })
        return bookmarked.intersection(ayahs.map { "\($0.surahID):\($0.number)" })
    }

    var body: some View {
        if abs(page - selection) <= 1 {
            let data = store.page(page)
            let jump: QuranJumpTarget.Point? = {
                guard let target = jumpTarget,
                      data.ayahs.contains(where: { $0.surahID == target.surah && $0.number == target.ayah })
                else { return nil }
                return target
            }()
            QuranPageWebView(page: page,
                             ayahs: data.ayahs,
                             juzLabel: settings.t("الجزء \(QuranPageHTML.arabicDigits(data.juzID))",
                                                  "Juz \(data.juzID)"),
                             bandSurahName: data.surahNames,
                             bookmarkedAyahs: bookmarkedKeys(data.ayahs),
                             jumpAyah: jump)
        } else {
            ZStack {
                QuranPalette.paper.ignoresSafeArea()
                VStack(spacing: 10) {
                    Image(systemName: "seal.fill")
                        .foregroundStyle(QuranPalette.darkGreen.opacity(0.35))
                    Text(QuranPageHTML.arabicDigits(page))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - One-shot target-ayah jump (athkar search → mushaf highlight)

/// One-shot jump target: the athkar search sets (surah, ayah) right before
/// pushing the mushaf; QuranPagesView takes it on appear and the matched ayah's
/// span renders with the olive-gold `.jump` highlight (see QuranPageHTML).
/// Cleared after the first paint (taken on appear) so nothing lingers.
enum QuranJumpTarget {
    struct Point: Equatable {
        let surah: Int
        let ayah: Int
    }

    private static var pending: Point?

    static func set(surah: Int, ayah: Int) {
        pending = Point(surah: surah, ayah: ayah)
    }

    /// Read-and-clear: only the push that follows the search highlight consumes it.
    static func take() -> Point? {
        defer { pending = nil }
        return pending
    }
}

// MARK: - Khatmah / last-read page

enum QuranPagesTracker {
    private static let key = "quranLastPage"
    /// Fresh in-store when the mushaf is opened at a page, mirroring the
    /// original stat cards' per-card "اليوم · 6:00 م" read stamps.
    private static let dateKey = "quranLastPageDate"

    static func restore() -> Int {
        let stored = UserDefaults.standard.object(forKey: key) as? Int ?? 1
        return min(max(stored, 1), 604)
    }

    /// The stored page or nil (never-opened mushaf) — the المصحف stats cards
    /// show "—" placeholders then; restore() keeps the 1-page default.
    static func storedPage() -> Int? {
        guard let stored = UserDefaults.standard.object(forKey: key) as? Int else {
            return nil
        }
        return min(max(stored, 1), 604)
    }

    static func lastReadDate() -> Date? {
        UserDefaults.standard.object(forKey: dateKey) as? Date
    }

    static func save(_ page: Int) {
        guard (1...604).contains(page) else { return }
        UserDefaults.standard.set(page, forKey: key)
        UserDefaults.standard.set(Date(), forKey: dateKey)
    }
}

// MARK: - Page data (own read-only connection; Data/ files stay untouched)

final class QuranPageStore: ObservableObject {
    struct PageData {
        let page: Int
        let ayahs: [QuranAyah]
        let juzID: Int
        let surahNames: String
    }

    final class JuzSection: Identifiable {
        let id: Int
        let name: String
        var rows: [(page: Int, names: String)] = []

        init(id: Int, name: String) {
            self.id = id
            self.name = name
        }
    }

    private var db: OpaquePointer?
    private var ayahsStmt: OpaquePointer?
    private var pageStmt: OpaquePointer?
    private var juzStmt: OpaquePointer?
    private var pageCache: [Int: PageData] = [:]
    private var sections: [JuzSection]?
    private let queue = DispatchQueue(label: "dev.dikhr.quranpages")

    init() {
        guard let url = Bundle.main.url(forResource: "Quran", withExtension: "sqlite") else { return }
        var pointer: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &pointer, flags, nil) == SQLITE_OK else { return }
        db = pointer
        ayahsStmt = prepare("SELECT id, surah_id, number, text, page FROM ayah WHERE page = ? ORDER BY id")
        pageStmt = prepare("SELECT juz_id, surah_name FROM pages WHERE id = ?")
        juzStmt = prepare("""
            SELECT p.id, p.surah_name, j.id, j.name FROM pages p
            JOIN juz j ON j.id = p.juz_id ORDER BY p.id
            """)
    }

    deinit {
        [ayahsStmt, pageStmt, juzStmt].forEach { sqlite3_finalize($0) }
        if let db { sqlite3_close_v2(db) }
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard let db, sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        return stmt
    }

    func page(_ number: Int) -> PageData {
        queue.sync {
            if let cached = pageCache[number] { return cached }
            var ayahs: [QuranAyah] = []
            var juzID = 0
            var names = ""
            if let stmt = ayahsStmt {
                sqlite3_reset(stmt)
                sqlite3_bind_int64(stmt, 1, Int64(number))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    ayahs.append(QuranAyah(
                        id: Int(sqlite3_column_int64(stmt, 0)),
                        surahID: Int(sqlite3_column_int64(stmt, 1)),
                        number: Int(sqlite3_column_int64(stmt, 2)),
                        text: String(cString: sqlite3_column_text(stmt, 3)),
                        page: Int(sqlite3_column_int64(stmt, 4))))
                }
                sqlite3_reset(stmt)
            }
            if let stmt = pageStmt {
                sqlite3_reset(stmt)
                sqlite3_bind_int64(stmt, 1, Int64(number))
                if sqlite3_step(stmt) == SQLITE_ROW {
                    juzID = Int(sqlite3_column_int64(stmt, 0))
                    names = String(cString: sqlite3_column_text(stmt, 1))
                }
                sqlite3_reset(stmt)
            }
            let data = PageData(page: number, ayahs: ayahs, juzID: juzID, surahNames: names)
            pageCache[number] = data
            return data
        }
    }

    /// 30 juz sections, each with its printed pages and the surah names on them.
    func juzSections() -> [JuzSection] {
        queue.sync {
            if let sections { return sections }
            var byID: [Int: JuzSection] = [:]
            var order: [JuzSection] = []
            if let stmt = juzStmt {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let pageID = Int(sqlite3_column_int64(stmt, 0))
                    let names = String(cString: sqlite3_column_text(stmt, 1))
                    let juzID = Int(sqlite3_column_int64(stmt, 2))
                    let juzName = String(cString: sqlite3_column_text(stmt, 3))
                    if byID[juzID] == nil {
                        let section = JuzSection(id: juzID, name: juzName)
                        byID[juzID] = section
                        order.append(section)
                    }
                    byID[juzID]?.rows.append((page: pageID, names: names))
                }
                sqlite3_reset(juzStmt)
            }
            sections = order
            return order
        }
    }
}

// MARK: - Jump-to-page sheet (all 1–604, sectioned by juz)

struct QuranPageListSheet: View {
    let store: QuranPageStore
    let current: Int
    let onPick: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(store.juzSections()) { section in
                        Section("\(section.name)") {
                            ForEach(section.rows.indices, id: \.self) { index in
                                let row = section.rows[index]
                                Button {
                                    onPick(row.page)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(QuranPageHTML.arabicDigits(row.page))
                                            .font(.headline)
                                            .foregroundStyle(row.page == current
                                                             ? QuranPalette.darkGreen
                                                             : .secondary)
                                            Text(row.names)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            if row.page == current {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(QuranPalette.darkGreen)
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo(current, anchor: .center)
                }
            }
            .navigationTitle(DikhrStrings.tr("انتقل إلى صفحة", "Go to Page"))
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - Surah jump (a surah opens on its first printed page)

struct QuranSurahJumpSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    let surahs: [QuranSurah]
    let onPick: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [QuranSurah] {
        query.isEmpty ? surahs : surahs.filter { $0.name.contains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { surah in
                Button {
                    onPick(max(1, surah.page))
                    dismiss()
                } label: {
                    HStack {
                        ZStack {
                            Image(systemName: "seal.fill")
                                .foregroundStyle(QuranPalette.darkGreen.opacity(0.3))
                            Text("\(surah.id)")
                                .font(.caption2.bold())
                        }
                        Text(surah.name).font(.title3)
                        Spacer()
                        Text(settings.t("صفحة \(QuranPageHTML.arabicDigits(surah.page))",
                                        "Page \(surah.page)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $query, prompt: settings.t("ابحث عن سورة", "Search for a surah"))
            .navigationTitle(settings.t("السور", "Surahs"))
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
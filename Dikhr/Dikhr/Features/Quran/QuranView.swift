import SwiftUI

struct QuranView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var surahs: [QuranSurah] = []
    @State private var query = ""
    @State private var results: [QuranAyah] = []
    @State private var path: [QuranSurah] = []
    @State private var lastRead: (surah: Int, ayah: Int)? = QuranBookmarkStore.lastRead()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let lastRead, let surah = surahs.first(where: { $0.id == lastRead.surah }) {
                    Section(settings.t("آخِر قراءة", "Last Read")) {
                        Button {
                            path = [surah]
                        } label: {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(.accent)
                                VStack(alignment: .leading) {
                                    Text(surah.name).font(.headline)
                                    Text(settings.t("الآية \(lastRead.ayah)", "Ayah \(lastRead.ayah)"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if query.isEmpty {
                    Section {
                        ForEach(surahs) { surah in
                            NavigationLink(value: surah) {
                                HStack {
                                    ZStack {
                                        Image(systemName: "seal.fill")
                                            .font(.title3)
                                            .foregroundStyle(.tint.opacity(0.30))
                                        Text("\(surah.id)")
                                            .font(.caption2.bold())
                                    }
                                    Text(surah.name).font(.title3)
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text(settings.t("\(surah.ayahCount) آية", "\(surah.ayahCount) ayahs"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(settings.t("صفحة \(surah.page)", "Page \(surah.page)"))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                } else if !results.isEmpty {
                    Section(settings.t("نتائج البحث", "Search Results")) {
                        ForEach(results) { ayah in
                            Button {
                                if let s = surahs.first(where: { $0.id == ayah.surahID }) {
                                    path = [s]
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ayah.text)
                                        .font(.system(size: 19, design: .serif))
                                        .foregroundStyle(.primary)
                                        .lineSpacing(8)
                                    Text(surahLabel(ayah))
                                        .font(.caption2)
                                        .foregroundStyle(.tint)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(settings.t("القرآن", "Quran"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        QuranPagesView()
                    } label: {
                        Label(settings.t("المصحف المطبوع", "Printed Mushaf"), systemImage: "book.pages")
                    }
                }
            }
            .searchable(text: $query, prompt: settings.t("ابحث في القرآن", "Search the Quran"))
            .onChange(of: query) { _, q in
                results = q.count > 1 ? QuranDatabase.shared.search(q) : []
            }
            .navigationDestination(for: QuranSurah.self) { surah in
                QuranSurahView(surah: surah)
            }
            .onAppear {
                if surahs.isEmpty { surahs = QuranDatabase.shared.surahs() }
                if let push = ProcessInfo.processInfo.environment["DIKHR_SURAH"],
                   let id = Int(push), let surah = surahs.first(where: { $0.id == id }) {
                    path = [surah]
                }
            }
        }
    }

    private func surahLabel(_ ayah: QuranAyah) -> String {
        if let s = surahs.first(where: { $0.id == ayah.surahID }) {
            return settings.t("\(s.name) \u{2022} آية \(ayah.number)",
                              "\(s.name) \u{2022} ayah \(ayah.number)")
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
        UserDefaults.standard.set(["surah": surahID, "ayah": ayah], forKey: "quranLastRead")
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
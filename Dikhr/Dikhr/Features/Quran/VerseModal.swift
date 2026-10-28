import SwiftUI
import AVFoundation

/// Quran green lives in QuranPalette; the modal's interactive accents use the
/// app's teal (#018F9E) — declared here to keep Data/App/ untouched.
enum VerseModalPalette {
    static let teal = Color(light: Color(red: 1/255, green: 143/255, blue: 158/255),
                            dark: Color(red: 20/255, green: 178/255, blue: 193/255))
}

/// Reciters streamed from everyayah.com/data/<folder>/<SSSAAA>.mp3 — the same
/// public hosts the original's ReciterPickerView / AthkarReciterDownload fed.
/// Folder names verified with live HTTP probes (Shaatree_128kbps and
/// Moaal_128kbps returned 404 and were trimmed).
struct QuranReciter: Identifiable, Hashable {
    let folder: String
    let name: String

    var id: String { folder }

    static let reciters: [QuranReciter] = [
        QuranReciter(folder: "Alafasy_128kbps",
                     name: "الصوت الأصلي - الشيخ مشاري العفاسي"),
        QuranReciter(folder: "Abdul_Basit_Murattal_192kbps",
                     name: "الشيخ عبد الباسط عبد الصمد (مرتل)"),
        QuranReciter(folder: "Abdurrahmaan_As-Sudais_192kbps",
                     name: "الشيخ عبدالرحمن السديس"),
        QuranReciter(folder: "Hudhaify_128kbps",
                     name: "الشيخ علي الحذيفي"),
        QuranReciter(folder: "Minshawy_Murattal_128kbps",
                     name: "الشيخ محمد صديق المنشاوي (مرتل)"),
        QuranReciter(folder: "Husary_128kbps",
                     name: "الشيخ محمود خليل الحصري"),
        QuranReciter(folder: "Ghamadi_40kbps",
                     name: "الشيخ سعد الغامدي"),
        QuranReciter(folder: "Ayman_Sowaid_64kbps",
                     name: "الشيخ أيمن سويد"),
        QuranReciter(folder: "Yasser_Ad-Dussary_128kbps",
                     name: "الشيخ ياسر الدوسري"),
        QuranReciter(folder: "Mohammad_al_Tablaway_128kbps",
                     name: "الشيخ محمد الطبلاوي"),
        QuranReciter(folder: "Abdullah_Basfar_192kbps",
                     name: "الشيخ عبد الله بصفر"),
    ]
}

/// Selection persistence — Dikhr's own key plus a presence marker mirroring the
/// original's `quranStorage.reciter.<folder>` key namespace.
enum QuranReciterStore {
    static let defaultFolder = "Alafasy_128kbps"
    private static let selectionKey = "selectedReciterFolder"

    static var selected: QuranReciter {
        QuranReciter.reciters.first(where: { $0.folder ==
            UserDefaults.standard.string(forKey: selectionKey) }) ?? QuranReciter.reciters[0]
    }

    static func select(_ reciter: QuranReciter) {
        UserDefaults.standard.set(reciter.folder, forKey: selectionKey)
        // Mirror the original's per-reciter storage marker.
        UserDefaults.standard.set(true, forKey: "quranStorage.reciter.\(reciter.folder)")
    }
}

/// Streams one ayah's recitation, with an optional download-to-cache so it can
/// play offline from a per-reciter cache directory.
@MainActor
final class VerseAudioPlayer: NSObject, ObservableObject {
    static let shared = VerseAudioPlayer()

    @Published var isPlaying = false
    @Published var isDownloading = false
    @Published var isCached = false

    private var player: AVPlayer?
    private var playedFolder = ""
    private var playedKey = ""
    /// Published so per-tile play/pause icons re-render when the playing
    /// surah SWITCHES (tapping a different tile while playing moves playback);
    /// isPlaying alone doesn't change on a switch.
    @Published private(set) var currentlyPlaying: (surah: Int, ayah: Int)?

    static func remoteURL(reciter: String, surah: Int, ayah: Int) -> URL {
        let key = String(format: "%03d%03d", surah, ayah)
        return URL(string: "https://everyayah.com/data/\(reciter)/\(key).mp3")!
    }

    static var cacheDirectory: URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("QuranAudio/\(QuranReciterStore.selected.folder)") else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cachedURL(surah: Int, ayah: Int) -> URL? {
        cacheDirectory?.appendingPathComponent(String(format: "%03d%03d.mp3", surah, ayah))
    }

    func isCached(surah: Int, ayah: Int) -> Bool {
        guard let url = VerseAudioPlayer.cachedURL(surah: surah, ayah: ayah) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func togglePlay(aayah: QuranAyah) {
        if isPlaying, let current = currentlyPlaying,
           current.surah == aayah.surahID, current.ayah == aayah.number {
            pause()
            return
        }
        play(aayah: aayah)
    }

    func play(aayah: QuranAyah) {
        player?.pause()
        let reciter = QuranReciterStore.selected
        let surah = aayah.surahID, ayah = aayah.number
        currentlyPlaying = (surah, ayah)
        playedFolder = reciter.folder
        playedKey = "\(surah):\(ayah)"
        isCached = isCached(surah: surah, ayah: ayah)

        let url: URL
        if let local = VerseAudioPlayer.cachedURL(surah: surah, ayah: ayah),
           FileManager.default.fileExists(atPath: local.path) {
            url = local
        } else {
            url = VerseAudioPlayer.remoteURL(reciter: reciter.folder, surah: surah, ayah: ayah)
        }

        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        newPlayer.play()
        isPlaying = true

        // Ended: reset state (the item's url key reflects the played ayah).
        NotificationCenter.default.addObserver(
            self, selector: #selector(itemDidEnd),
            name: .AVPlayerItemDidPlayToEndTime, object: newPlayer.currentItem)
    }

    @objc private func itemDidEnd() {
        isPlaying = false
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        currentlyPlaying = nil
    }

    /// Download-to-listen: save into the per-reciter cache dir for offline play.
    func download(aayah: QuranAyah) {
        guard !isDownloading, !isCached(surah: aayah.surahID, ayah: aayah.number) else { return }
        isDownloading = true
        let surah = aayah.surahID, ayah = aayah.number
        let remote = VerseAudioPlayer.remoteURL(reciter: QuranReciterStore.selected.folder,
                                                surah: surah, ayah: ayah)
        URLSession.shared.downloadTask(with: remote) { [weak self] atURL, _, _ in
            guard let self else { return }
            defer { Task { @MainActor in self.isDownloading = false } }
            guard let atURL else { return }
            guard let dest = VerseAudioPlayer.cachedURL(surah: surah, ayah: ayah) else { return }
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.moveItem(at: atURL, to: dest)
                Task { @MainActor in
                    self.isCached = self.isCached(surah: surah, ayah: ayah)
                }
            } catch {}
        }.resume()
    }
}

/// آية modal — the original's verse-tap sheet: play the verse (reciter picker +
/// download), read its تفسير, and bookmark it (persistently highlighted).
struct VerseModal: View {
    @EnvironmentObject private var settings: SettingsStore
    let aayah: QuranAyah
    let surah: QuranSurah
    @Binding var bookmarked: Bool
    @StateObject private var audio = VerseAudioPlayer.shared
    @Environment(\.dismiss) private var dismiss

    private var reciter: QuranReciter { QuranReciterStore.selected }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // The verse itself (Uthmanic, RTL, green markers per palette).
                    // Drawn ring instead of the font-composed ayah sign:
                    // SwiftUI shaping splits U+06DD into a second empty ring.
                    HStack(spacing: 8) {
                        Text(aayah.text)
                            .font(.quranUthmani)
                        AthkarCircledNumber(value: aayah.number, diameter: 22)
                    }
                        .lineSpacing(14)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(Color(.label))
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(QuranPalette.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(QuranPalette.darkGreen.opacity(0.25), lineWidth: 1)
                        )

                    // تشغيل the verse
                    GroupBox {
                        HStack(spacing: 14) {
                            Button {
                                audio.togglePlay(aayah: aayah)
                            } label: {
                                Label(audio.isPlaying ? "إيقاف" : "تشغيل",
                                      systemImage: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(QuranPalette.darkGreen))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                audio.download(aayah: aayah)
                            } label: {
                                Image(systemName: audio.isCached
                                        ? "checkmark.circle.fill"
                                        : (audio.isDownloading ? "arrow.down.circle" : "arrow.down.circle.fill"))
                                    .font(.title3)
                                    .foregroundStyle(audio.isCached ? QuranPalette.darkGreen : VerseModalPalette.teal)
                            }
                            .buttonStyle(.borderless)
                            .disabled(audio.isDownloading || audio.isCached)
                            .accessibilityLabel(settings.t("تنزيل للسماع بدون إنترنت",
                                                           "Download to listen offline"))
                        }

                        NavigationLink {
                            VerseReciterPicker()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.wave.2")
                                    .foregroundStyle(VerseModalPalette.teal)
                                Text(settings.t("القارئ", "Reciter"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(reciter.name)
                                    .font(.subheadline)
                                    .foregroundStyle(QuranPalette.darkGreen)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.top, 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .groupBoxStyle(VerseModalGroupBoxStyle())

                    // التفسير
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "text.justify")
                                    .foregroundStyle(VerseModalPalette.teal)
                                Text(settings.t("التفسير الميسر", "Clear Tafsir"))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(QuranPalette.darkGreen)
                            }
                            if let taf = TafseerDatabase.shared.tafseer(surah: aayah.surahID, ayah: aayah.number) {
                                Text(taf)
                                    .font(.callout)
                                    .lineSpacing(8)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(settings.t("لا يوجد تفسير لهذه الآية", "No tafsir for this ayah"))
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .groupBoxStyle(VerseModalGroupBoxStyle())

                    // Bookmark — highlights the verse persistently (original .highlight)
                    Button {
                        if bookmarked {
                            QuranBookmarkStore.remove(surahID: aayah.surahID, ayah: aayah.number)
                        } else {
                            QuranBookmarkStore.add(surahID: aayah.surahID, ayah: aayah.number)
                        }
                        bookmarked = QuranBookmarkStore.isBookmarked(surahID: aayah.surahID, ayah: aayah.number)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(bookmarked ? VerseModalPalette.teal : .secondary)
                            Text(bookmarked
                                 ? settings.t("محفوظة — إزالة", "Bookmarked — Remove")
                                 : settings.t("حفظ الآية", "Bookmark the verse"))
                                .font(.headline)
                                .foregroundStyle(bookmarked ? VerseModalPalette.teal : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(bookmarked ? VerseModalPalette.teal.opacity(0.10) : Color(.tertiarySystemFill)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(settings.t("\(surah.name) • آية \(aayah.number)",
                                        "\(surah.name) • Ayah \(aayah.number)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .onAppear {
                // Reciter can change between opens; refresh the cached flag.
                audio.isCached = audio.isCached(surah: aayah.surahID, ayah: aayah.number)
            }
            .onDisappear {
                if let current = audio.currentlyPlaying,
                   current.surah == aayah.surahID, current.ayah == aayah.number {
                    audio.pause()
                }
            }
        }
    }
}

/// Verse-shaped GroupBox: hairline + paper fill, per brief.
struct VerseModalGroupBoxStyle: GroupBoxStyle {
    var title: Text = Text("")
    var caption: Text = Text("")

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.content
                .padding(14)
                .background(QuranPalette.paper)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                    QuranPalette.darkGreen.opacity(0.14), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// القارئ — inline reciter list; selection persisted under
/// "selectedReciterFolder" (mirror of the original's picker behavior).
struct VerseReciterPicker: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var selection: QuranReciter = QuranReciterStore.selected

    var body: some View {
        List(QuranReciter.reciters) { reciter in
            Button {
                QuranReciterStore.select(reciter)
                selection = reciter
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(reciter.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(reciter.folder)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if reciter == selection {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(QuranPalette.darkGreen)
                    }
                }
            }
        }
        .navigationTitle(settings.t("اختر القارئ", "Choose a Reciter"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
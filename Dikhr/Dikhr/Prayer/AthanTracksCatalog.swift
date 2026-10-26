import Foundation
import AVFoundation

/// Full athan-track catalog extracted from the original app
/// (see notes/athan_tracks.json for the RE record):
/// - `part` tracks: the original's ≤30 s notification sounds ("جزء من الأذان …"),
///   shipped inside the original's bundle as Apple managed asset packs — the CDN
///   mirrors only full-length m4a counterparts, which we download when the .caf
///   is not present locally.
/// - `alarm` tracks: the FULL athan alarms served from the original's CDN
///   ("https://athkarapp.com/app/pro/athan/alarms/") which the original gates to
///   Pro; Dikhr mirrors that with `ProStore.isPro`.
///
/// Downloads go to the app container's Library/Sounds (shared with
/// AthanSoundStore) under `athan-track-<key>.<ext>` names so both
/// UNNotificationSound and AlarmKit can resolve them.
struct AthanTrack: Hashable, Identifiable {

    enum Section: String, Hashable {
        case parts
        case full
    }

    enum Source: Hashable {
        /// Bundled ≤30 s .caf of the original (key = bundle file base name).
        case part(fileKey: String)
        /// Full-length remote alarm file on the CDN (e.g. "athan-maka.m4a").
        case alarm(remoteFile: String)
    }

    let key: String
    let arabicName: String
    let englishName: String
    let section: Section
    let source: Source
    /// CDN counterpart the picker can fetch (nil = not downloadable, bundle-only).
    let cdnCounterpart: String?
    var id: String { key }
}

enum AthanTracksCatalog {

    static let cdnBaseURL = URL(string: "https://athkarapp.com/app/pro/athan/alarms/")!

    /// MARK: — Part tracks (أجزاء الأذان / أصوات إشعار الأذان, ≤30 s in the original)
    static let parts: [AthanTrack] = [
        .init(key: "athan-jordan-short", arabicName: "جزء من الأذان - الأردن", englishName: "Part of Athan — Jordan", section: .parts, source: .part(fileKey: "athan-jordan-short.caf"), cdnCounterpart: "athan-jordan.m4a"),
        .init(key: "athan-alquds-short", arabicName: "جزء من الأذان - القدس", englishName: "Partial Athan — Al-Quds", section: .parts, source: .part(fileKey: "athan-alquds-short.caf"), cdnCounterpart: "athan-alquds.m4a"),
        .init(key: "athan-wadee-yamani-short", arabicName: "جزء من الأذان - وديع اليمني", englishName: "Partial Athan — Wadee Al-Yamani", section: .parts, source: .part(fileKey: "athan-wadee-yamani-short.caf"), cdnCounterpart: "athan-wadee-yamani.m4a"),
        .init(key: "athan-qatar-short", arabicName: "جزء من الأذان - قطر", englishName: "Partial Athan — Qatar", section: .parts, source: .part(fileKey: "athan-qatar-short.caf"), cdnCounterpart: "athan-qatar.m4a"),
        .init(key: "athan", arabicName: "جزء من الأذان - مشاري العفاسي", englishName: "Part of Athan — Mishary Alafasy", section: .parts, source: .part(fileKey: "athan.caf"), cdnCounterpart: "athan.m4a"),
        .init(key: "athan-maka", arabicName: "جزء من الأذان - مكة", englishName: "Part of Athan — Makkah", section: .parts, source: .part(fileKey: "athan-maka.caf"), cdnCounterpart: "athan-maka.m4a"),
        .init(key: "athan-uae", arabicName: "جزء من الأذان - الإمارات", englishName: "Part of Athan — UAE", section: .parts, source: .part(fileKey: "athan-uae.caf"), cdnCounterpart: "athan-uae.m4a"),
        .init(key: "athan-egypt", arabicName: "جزء من الأذان - مصر", englishName: "Part of Athan — Egypt", section: .parts, source: .part(fileKey: "athan-egypt.caf"), cdnCounterpart: "athan-egypt.m4a"),
        .init(key: "athan-fajr", arabicName: "جزء من الأذان - الفجر", englishName: "Part of Athan — Fajr", section: .parts, source: .part(fileKey: "athan-fajr.caf"), cdnCounterpart: "athan-fajr.m4a"),
        .init(key: "athan-q7tani", arabicName: "جزء من الأذان - ناصر القطامي", englishName: "Part of Athan — Nasser Al Qatami", section: .parts, source: .part(fileKey: "athan-q7tani.caf"), cdnCounterpart: "athan-q7tani.m4a"),
        .init(key: "athan-madina", arabicName: "جزء من الأذان - الحرم النبوي", englishName: "Part of Athan — Madina", section: .parts, source: .part(fileKey: "athan-madina.caf"), cdnCounterpart: "athan-madina.m4a"),
        .init(key: "athan-saqaaf", arabicName: "جزء من الأذان - هاشم السقاف", englishName: "Part of Athan — Hisham Al-Saqqaf", section: .parts, source: .part(fileKey: "athan-saqaaf.caf"), cdnCounterpart: "athan-saqaaf.m4a"),
        .init(key: "athan-abdlaziz-mjid", arabicName: "جزء من الأذان - الشيخ عبدالعزيز بن ماجد", englishName: "Part of Athan — Sheikh Abdulaziz bin Majid", section: .parts, source: .part(fileKey: "athan-abdlaziz-mjid.caf"), cdnCounterpart: "athan-abdlaziz-mjid.m4a"),
        .init(key: "athan-qasaas", arabicName: "جزء من الأذان - محمد مروان قصاص", englishName: "Part of Athan — Mohammad Marwan Qassas", section: .parts, source: .part(fileKey: "athan-qasaas.caf"), cdnCounterpart: "athan-qasaas.m4a"),
        .init(key: "athan-saeedAlZedaan", arabicName: "جزء من الأذان - سعيد آل زيدان", englishName: "Part of Athan — Saeed Al Zedaan", section: .parts, source: .part(fileKey: "athan-saeedAlZedaan.caf"), cdnCounterpart: nil),
        .init(key: "athan-haya", arabicName: "حي على الصلاة", englishName: "Hayya ala as-Salah", section: .parts, source: .part(fileKey: "athan-haya.caf"), cdnCounterpart: nil),
        .init(key: "shortAthan1", arabicName: "تكبيرتان 1", englishName: "Takbiratan 1", section: .parts, source: .part(fileKey: "shortAthan1.caf"), cdnCounterpart: nil),
        .init(key: "shortAthan2", arabicName: "تكبيرتان 2", englishName: "Takbiratan 2", section: .parts, source: .part(fileKey: "shortAthan2.caf"), cdnCounterpart: nil),
    ]

    /// MARK: — Full alarm tracks (الأذان كامل من منبه حقيقي, CDN-gated to Pro in the original)
    static let full: [AthanTrack] = [
        .init(key: "full-athan-maka", arabicName: "أذان كامل - مكة", englishName: "Full Athan — Makkah", section: .full, source: .alarm(remoteFile: "athan-maka.m4a"), cdnCounterpart: "athan-maka.m4a"),
        .init(key: "full-athan-madina", arabicName: "أذان كامل - المدينة", englishName: "Full Athan — Madinah", section: .full, source: .alarm(remoteFile: "athan-madina.m4a"), cdnCounterpart: "athan-madina.m4a"),
        .init(key: "full-athan-uae", arabicName: "أذان كامل - الإمارات", englishName: "Full Athan — UAE", section: .full, source: .alarm(remoteFile: "athan-uae.m4a"), cdnCounterpart: "athan-uae.m4a"),
        .init(key: "full-athan-egypt", arabicName: "أذان كامل - مصر", englishName: "Full Athan — Egypt", section: .full, source: .alarm(remoteFile: "athan-egypt.m4a"), cdnCounterpart: "athan-egypt.m4a"),
        .init(key: "full-athan-qatar", arabicName: "أذان كامل - قطر", englishName: "Full Athan — Qatar", section: .full, source: .alarm(remoteFile: "athan-qatar.m4a"), cdnCounterpart: "athan-qatar.m4a"),
        .init(key: "full-athan-jordan", arabicName: "أذان كامل - الأردن", englishName: "Full Athan — Jordan", section: .full, source: .alarm(remoteFile: "athan-jordan.m4a"), cdnCounterpart: "athan-jordan.m4a"),
        .init(key: "full-athan-alquds", arabicName: "أذان كامل - القدس", englishName: "Full Athan — Al-Quds", section: .full, source: .alarm(remoteFile: "athan-alquds.m4a"), cdnCounterpart: "athan-alquds.m4a"),
        .init(key: "full-athan-q7tani", arabicName: "أذان كامل - ناصر القطامي", englishName: "Full Athan — Nasser Al Qatami", section: .full, source: .alarm(remoteFile: "athan-q7tani.m4a"), cdnCounterpart: "athan-q7tani.m4a"),
        .init(key: "full-athan-saqaaf", arabicName: "أذان كامل - هاشم السقاف", englishName: "Full Athan — Hisham As-Saqqaf", section: .full, source: .alarm(remoteFile: "athan-saqaaf.m4a"), cdnCounterpart: "athan-saqaaf.m4a"),
        .init(key: "full-athan-abdlaziz-mjid", arabicName: "أذان كامل - عبدالعزيز بن ماجد", englishName: "Full Athan — Abdulaziz bin Majid", section: .full, source: .alarm(remoteFile: "athan-abdlaziz-mjid.m4a"), cdnCounterpart: "athan-abdlaziz-mjid.m4a"),
        .init(key: "full-athan-qasaas", arabicName: "أذان كامل - محمد مروان قصاص", englishName: "Full Athan — Mohammad Marwan Qassas", section: .full, source: .alarm(remoteFile: "athan-qasaas.m4a"), cdnCounterpart: "athan-qasaas.m4a"),
        .init(key: "full-athan-abdulbasit", arabicName: "أذان كامل - عبدالباسط عبدالصمد", englishName: "Full Athan — Abdul Basit Abdul Samad", section: .full, source: .alarm(remoteFile: "athan_abdulbasit.m4a"), cdnCounterpart: "athan_abdulbasit.m4a"),
        .init(key: "full-athan-ghamdi", arabicName: "أذان كامل - سعد الغامدي", englishName: "Full Athan — Saad Al Ghamdi", section: .full, source: .alarm(remoteFile: "athan_saad_alghamdi.m4a"), cdnCounterpart: "athan_saad_alghamdi.m4a"),
        .init(key: "full-athan-nufais", arabicName: "أذان كامل - أحمد النفيس", englishName: "Full Athan — Ahmed Al Nufais", section: .full, source: .alarm(remoteFile: "athan_ahmed_alnufais.m4a"), cdnCounterpart: "athan_ahmed_alnufais.m4a"),
        .init(key: "full-athan-abdulmajeed-sarihi", arabicName: "أذان كامل - عبدالمجيد السريحي", englishName: "Full Athan — Abdul Majeed As-Surayhi", section: .full, source: .alarm(remoteFile: "athan-abdulmajeed-sarihi.m4a"), cdnCounterpart: "athan-abdulmajeed-sarihi.m4a"),
        .init(key: "full-athan-wadee-yamani", arabicName: "أذان كامل - وديع اليمني", englishName: "Full Athan — Wadee Al Yamani", section: .full, source: .alarm(remoteFile: "athan-wadee-yamani.m4a"), cdnCounterpart: "athan-wadee-yamani.m4a"),
        .init(key: "full-athan-raed-kurdi", arabicName: "أذان كامل - رعد الكردي", englishName: "Full Athan — Raad Al Kurdi", section: .full, source: .alarm(remoteFile: "araad-kurdi.m4a"), cdnCounterpart: "araad-kurdi.m4a"),
        .init(key: "full-athan-afasy", arabicName: "أذان كامل - مشاري العفاسي", englishName: "Full Athan — Mishary Al Afasy", section: .full, source: .alarm(remoteFile: "athan.m4a"), cdnCounterpart: "athan.m4a"),
        .init(key: "fajr-full-default", arabicName: "أذان الفجر كامل", englishName: "Fajr Full Athan", section: .full, source: .alarm(remoteFile: "FajrFullAthan.m4a"), cdnCounterpart: "FajrFullAthan.m4a"),
        .init(key: "fajr-full-qatami", arabicName: "أذان الفجر - ناصر القطامي", englishName: "Fajr Athan — Nasser Al Qatami", section: .full, source: .alarm(remoteFile: "athan-fajr-qatami.m4a"), cdnCounterpart: "athan-fajr-qatami.m4a"),
    ]

    static var all: [AthanTrack] { parts + full }

    static func track(forKey key: String) -> AthanTrack? {
        all.first { $0.key == key }
    }
}

/// Parallel downloader + selection store for the catalog. Does NOT edit
/// AthanSoundStore: mirrored with the same storage conventions
/// (Library/Sounds for container files, same per-prayer defaults shape).
enum AthanTrackStore {

    private static func perPrayerKey(_ prayer: String) -> String {
        "athanTrack-\(prayer)"
    }

    /// Prefix so AthanSoundPickerView can filter out catalog downloads from the
    /// plain imported-files list (they get their own catalog rows).
    static let downloadedFilePrefix = "athan-track-"

    // MARK: selection (per prayer; mirrored into AthanSoundStore by the picker)

    static func selectedKey(for prayer: String) -> String? {
        DikhrShared.defaults.string(forKey: perPrayerKey(prayer))
    }

    static func selectedTrack(for prayer: String) -> AthanTrack? {
        selectedKey(for: prayer).flatMap { AthanTracksCatalog.track(forKey: $0) }
    }

    static func setSelected(_ track: AthanTrack, for prayer: String) {
        DikhrShared.defaults.set(track.key, forKey: perPrayerKey(prayer))
        // Mirror into AthanSoundStore so the notification path (AlarmScheduler)
        // keeps behaving without any edit there: bundled .caf mirrors as
        // .bundled (stageForNotifications can copy it), CDN downloads into
        // Library/Sounds mirror as .imported. AlarmKit goes through
        // selectedTrack(for:) first instead.
        if let url = localFileURL(for: track) {
            let file = url.lastPathComponent
            if url.path.contains(".app/") {
                AthanSoundStore.setSelected(.bundled(file), for: prayer)
            } else {
                AthanSoundStore.setSelected(.imported(file), for: prayer)
            }
        }
    }

    static func clearSelection(for prayer: String) {
        DikhrShared.defaults.removeObject(forKey: perPrayerKey(prayer))
    }

    // MARK: local availability

    /// Where a track's audio lives locally, if anywhere:
    /// - bundled part .caf in the app bundle (mirrors the original's asset packs)
    /// - downloaded m4a mirrored from the CDN in Library/Sounds
    static func localFileURL(for track: AthanTrack) -> URL? {
        switch track.source {
        case .part(let fileKey):
            let base = (fileKey as NSString).deletingPathExtension
            let ext = (fileKey as NSString).pathExtension
            if let bundled = Bundle.main.url(forResource: base, withExtension: ext) {
                return bundled
            }
            if let counterpart = track.cdnCounterpart {
                let downloaded = AthanSoundStore
                    .librarySoundsDirectory()
                    .appendingPathComponent(downloadedName(base: (counterpart as NSString).deletingPathExtension,
                                                           ext: (counterpart as NSString).pathExtension))
                if FileManager.default.fileExists(atPath: downloaded.path) { return downloaded }
            }
            return nil
        case .alarm(let remoteFile):
            let base = (remoteFile as NSString).deletingPathExtension
            let ext = (remoteFile as NSString).pathExtension
            let downloaded = AthanSoundStore
                .librarySoundsDirectory()
                .appendingPathComponent(downloadedName(base: base, ext: ext))
            return FileManager.default.fileExists(atPath: downloaded.path) ? downloaded : nil
        }
    }

    /// File name for AlarmKit's AlertSound.named — INCLUDING the extension
    /// (required; see AthanAlarmController for the documented constraint).
    static func alarmSoundName(for track: AthanTrack) -> String? {
        localFileURL(for: track)?.lastPathComponent
    }

    private static func downloadedName(base: String, ext: String) -> String {
        "\(downloadedFilePrefix)\(base).\(ext)"
    }

    static func isDownloaded(_ track: AthanTrack) -> Bool {
        localFileURL(for: track) != nil
    }

    // MARK: download (URLSession, same pattern as AthanSoundStore.downloads)

    enum DownloadError: LocalizedError {
        case noCounterpart
        public var errorDescription: String? {
            switch self {
            case .noCounterpart:
                return DikhrStrings.tr("لا يوجد ملف للتنزيل لهذا المسار — يأتي مع حزمة التطبيق", "No downloadable file for this track — shipped inside the app bundle")
            }
        }
    }

    @discardableResult
    static func download(_ track: AthanTrack) async throws -> URL {
        guard let remoteFile = track.cdnCounterpart else { throw DownloadError.noCounterpart }
        let url = AthanTracksCatalog.cdnBaseURL.appendingPathComponent(remoteFile)
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "athan-tracks", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: DikhrStrings.tr("تعذر تنزيل الملف", "Could not download the file")])
        }
        let base = (remoteFile as NSString).deletingPathExtension
        let ext = (remoteFile as NSString).pathExtension
        let target = AthanSoundStore
            .librarySoundsDirectory()
            .appendingPathComponent(downloadedName(base: base, ext: ext))
        try data.write(to: target, options: .atomic)
        return target
    }
}
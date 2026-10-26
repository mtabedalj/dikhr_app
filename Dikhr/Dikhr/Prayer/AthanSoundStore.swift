import Foundation
import AVFoundation

/// Per-prayer athan sound management, mirroring the original's
/// "Athan Assets" + "Re-download Athan" feature:
/// - builtin synthesized chimes (bundled .caf)
/// - sounds imported from the Files app
/// - optional downloads from a user-configured URL (their CDN equivalent)
/// Selection is stored per prayer and used by AlarmScheduler for notifications.
/// iOS notification sounds must be caf/aiff/wav; mp3/m4a imports are playable
/// in-app but flagged not-notification-safe.
enum AthanSoundStore {

    enum Sound: Hashable, Identifiable {
        case defaultSystem
        case silent
        case bundled(String)   // file name inside the app bundle (AthanSounds)
        case imported(String)  // file name inside Library/Sounds

        var id: String { storageKey }

        var label: String {
            switch self {
            case .defaultSystem: return "النظام الافتراضي"
            case .silent: return "بلا صوت"
            case .bundled(let n): return prettyBase(n)
            case .imported(let n): return prettyBase(n) + " (مستورد)"
            }
        }

        var storageKey: String {
            switch self {
            case .defaultSystem: return "default"
            case .silent: return "silent"
            case .bundled(let n): return "bundled:\(n)"
            case .imported(let n): return "imported:\(n)"
            }
        }

        var fileBaseName: String? {
            switch self {
            case .defaultSystem, .silent: return nil
            case .bundled(let n), .imported(let n): return n
            }
        }

        /// Notifications only play caf/aiff/wav.
        var notificationSafe: Bool {
            guard let file = fileBaseName else { return true }
            return ["caf", "aiff", "wav"].contains((file as NSString).pathExtension.lowercased())
        }

        static func fromStorageKey(_ raw: String) -> Sound {
            if raw == "silent" { return .silent }
            if raw.hasPrefix("bundled:") { return .bundled(String(raw.dropFirst(8))) }
            if raw.hasPrefix("imported:") { return .imported(String(raw.dropFirst(9))) }
            return .defaultSystem
        }
    }

    private static let builtinLabels = [
        "athan-calm": "هدوء",
        "athan-chime": "نقوس",
        "athan-noble": "نبيل",
    ]

    private static func prettyBase(_ file: String) -> String {
        let base = (file as NSString).deletingPathExtension
        if let label = builtinLabels[base] { return label }
        return base.replacingOccurrences(of: "-", with: " ")
    }

    // MARK: selection (per prayer, app-group shared for extensions)

    static func selected(for prayer: String) -> Sound {
        let raw = DikhrShared.defaults.string(forKey: "athanSound-\(prayer)") ?? "default"
        return Sound.fromStorageKey(raw)
    }

    static func setSelected(_ sound: Sound, for prayer: String) {
        DikhrShared.defaults.set(sound.storageKey, forKey: "athanSound-\(prayer)")
        stageForNotifications(sound)
    }

    // MARK: catalogs

    static func builtinSounds() -> [Sound] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "caf", subdirectory: nil) else {
            return []
        }
        return urls
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix("athan") }
            .sorted()
            .map { Sound.bundled($0) }
    }

    static func importedSounds() -> [Sound] {
        ((try? FileManager.default.contentsOfDirectory(at: soundsDirectory(),
                                                       includingPropertiesForKeys: nil)) ?? [])
            .filter { ["caf", "aiff", "wav"].contains($0.pathExtension.lowercased()) }
            .map(\.lastPathComponent)
            .sorted()
            .map { Sound.imported($0) }
    }

    /// Notification sounds must live in the app container's Library/Sounds.
    static func librarySoundsDirectory() -> URL {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func soundsDirectory() -> URL { librarySoundsDirectory() }

    /// Stages the selected sound into Library/Sounds so notifications can play it.
    @discardableResult
    static func stageForNotifications(_ sound: Sound) -> String? {
        guard let file = sound.fileBaseName, sound.notificationSafe else { return nil }
        let target = librarySoundsDirectory().appendingPathComponent(file)
        if FileManager.default.fileExists(atPath: target.path) { return file }
        let ext = (file as NSString).pathExtension
        let base = (file as NSString).deletingPathExtension
        if case .bundled = sound,
           let bundled = Bundle.main.url(forResource: base, withExtension: ext) {
            try? FileManager.default.copyItem(at: bundled, to: target)
            return file
        }
        return nil
    }

    /// Imports a user-picked audio file into the sound library.
    static func importSound(from url: URL) async throws -> Sound {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard ["caf", "aiff", "wav", "mp3", "m4a"].contains(ext) else {
            throw NSError(domain: "athan", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "صيغة غير مدعومة (caf/aiff/wav/mp3/m4a)"])
        }
        let data = try Data(contentsOf: url)
        return try importSound(fromData: data, ext: ext)
    }

    /// Downloads an athan asset (the "Re-download Athan" path) and installs it.
    static func downloadSound(from remote: URL) async throws -> Sound {
        let (data, _) = try await URLSession.shared.data(from: remote)
        let ext = remote.pathExtension.lowercased().isEmpty ? "mp3" : remote.pathExtension.lowercased()
        return try importSound(fromData: data, ext: ext)
    }

    private static func importSound(fromData data: Data, ext: String) throws -> Sound {
        let stamp = Int(Date().timeIntervalSince1970)
        let target = soundsDirectory().appendingPathComponent("athan-import-\(stamp).\(ext)")
        try data.write(to: target)
        return .imported(target.lastPathComponent)
    }

    /// Preview playback in the picker.
    @MainActor
    static func preview(_ sound: Sound) -> AVAudioPlayer? {
        guard let file = sound.fileBaseName else { return nil }
        let ext = (file as NSString).pathExtension
        let base = (file as NSString).deletingPathExtension
        let localURL = soundsDirectory().appendingPathComponent(file)
        let url: URL? = Bundle.main.url(forResource: base, withExtension: ext)
            ?? (FileManager.default.fileExists(atPath: localURL.path) ? localURL : nil)
        guard let playURL = url else { return nil }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: playURL)
            player.volume = 0.8
            player.play()
            return player
        } catch {
            return nil
        }
    }
}
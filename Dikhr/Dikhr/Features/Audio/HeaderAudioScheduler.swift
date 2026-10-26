import Foundation
import AVFoundation
import SwiftUI

// MARK: - HeaderAudioSchedule.json (from the original bundle)
//
// Ground truth from /Applications/Athkar.app/Wrapper/athkar.app:
//   {"months": {"1": [<10 filenames>, ...], ...}} — one recitation clip chosen
//   per day of the month (10 clips per month, rotating by day). The original
//   downloaded the clip remotely (HeaderAudio_LastFilename /
//   HeaderAudio_MonthRetryAfter keys, HeaderAudioListView) and showed a compact
//   audio card in the app header ("استمع إلى تلاوة اليوم من بطاقة مختصرة،
//   وتحكّم بالتشغيل والتقدم، وتابع الاستماع دون انقطاع عند فتح العرض الكامل.").
// Dikhr ships only the schedule; the clip files themselves are user-supplied
// (copyrighted audio is not copied).

/// A scheduled header audio clip: month number + rotating index within the month.
struct HeaderAudioEntry: Identifiable, Equatable {
    let filename: String   // as listed in the JSON, e.g. "Obaid-Aflaha.mp3"
    let month: Int
    let day: Int

    var id: String { filename }

    /// Key used for audio file lookup, mirroring AthkarEntry.Audio (extensionless).
    var audioKey: String { (filename as NSString).deletingPathExtension }

    /// Human title derived from the file name (reciter–clip).
    var title: String {
        let base = audioKey
        let parts = base.split(separator: "-").map(String.init)
        if parts.count > 1 {
            return parts.dropFirst().joined(separator: " ")
        }
        return base
    }

    /// Reciter side of the file name when present (e.g. "Obaid-Aflaha" → "Obaid").
    var reciterName: String {
        let parts = audioKey.split(separator: "-")
        return parts.isEmpty ? audioKey : String(parts[0])
    }
}

enum HeaderAudioSchedule {
    private static var monthsCache: [String: [String]]?

    @discardableResult
    static func load() -> [String: [String]] {
        if let monthsCache { return monthsCache }
        guard let url = Bundle.main.url(forResource: "HeaderAudioSchedule", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let months = root["months"] as? [String: [String]]
        else { return [:] }
        monthsCache = months
        return months
    }

    /// The clip active for the given date's day. The month lists hold 10 clips;
    /// the day of the month selects `((day - 1) % count)` (rotates 1–10 → 11–20…).
    static func entry(for date: Date = .now) -> HeaderAudioEntry? {
        let months = load()
        guard !months.isEmpty else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        guard let list = months[String(month)], !list.isEmpty else { return nil }
        let index = (day - 1) % list.count
        return HeaderAudioEntry(filename: list[index], month: month, day: day)
    }

    /// Convenience API requested for header integration.
    static func currentEntry() -> HeaderAudioEntry? { entry() }

    // MARK: File resolution (user-supplied clips)

    static let audioExtensions = ["mp3", "m4a", "aac"]

    static func fileURL(for entry: HeaderAudioEntry) -> URL? {
        let appGroup = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DikhrShared.appGroupID)
        var directories: [URL] = []
        if let base = appGroup {
            directories.append(base.appendingPathComponent("HeaderAudio", isDirectory: true))
            directories.append(base.appendingPathComponent("Recitations", isDirectory: true))
        }
        directories.append(contentsOf: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .map { $0.appendingPathComponent("HeaderAudio", isDirectory: true) })

        let base = entry.audioKey
        // Exact name first (schedule carries ".mp3" in the stem list… the key is stem-only)
        for dir in directories {
            for ext in audioExtensions {
                let url = dir.appendingPathComponent(base + "." + ext)
                if FileManager.default.fileExists(atPath: url.path) { return url }
            }
        }
        // Bundled resources
        for ext in audioExtensions {
            if let url = Bundle.main.url(forResource: base, withExtension: ext) { return url }
            if let url = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "Audio") { return url }
        }
        return nil
    }

    /// Mirrors the original's __canShowHeaderAudioButton: the header card is only
    /// shown when the scheduled clip is actually present on device.
    static func isAvailable(for date: Date = .now) -> Bool {
        guard let entry = entry(for: date) else { return false }
        return fileURL(for: entry) != nil
    }
}

// MARK: - Player (AVQueuePlayer, same pattern as AudioManager)

/// AVQueuePlayer wrapper following `AudioManager`'s shape
/// (NotificationCenter end-of-item observer; no AVAudioPlayerDelegate),
/// extended with progress + seeking for the compact header card.
@MainActor
final class HeaderAudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var hasFile = false

    private var player: AVQueuePlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private(set) var entry: HeaderAudioEntry?

    /// Resolve availability + duration without creating the player (bar preview).
    func prepare(entry: HeaderAudioEntry) {
        if self.entry != entry {
            stop()
            self.entry = entry
        }
        hasFile = HeaderAudioSchedule.fileURL(for: entry) != nil
        guard hasFile, duration <= 0, let url = HeaderAudioSchedule.fileURL(for: entry) else { return }
        let asset = AVURLAsset(url: url)
        Task { [weak self] in
            if let d = try? await asset.load(.duration) {
                MainActor.assumeIsolated {
                    if self?.duration == 0 { self?.duration = d.seconds }
                }
            }
        }
    }

    func load(entry: HeaderAudioEntry, autoplay: Bool = true) {
        guard self.entry != entry else {
            if autoplay && !isPlaying { player?.play(); isPlaying = true }
            return
        }
        stop()
        self.entry = entry
        guard let url = HeaderAudioSchedule.fileURL(for: entry) else {
            hasFile = false
            return
        }
        hasFile = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(items: [item])
        player = queuePlayer
        installObservers(for: item, player: queuePlayer)
        duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
        if autoplay {
            queuePlayer.play()
            isPlaying = true
        }
    }

    private func installObservers(for item: AVPlayerItem, player: AVQueuePlayer) {
        removeObservers()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 10), queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentTime = time.seconds
                if let d = self?.player?.currentItem?.duration.seconds, d.isFinite {
                    self?.duration = d
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.duration = self?.currentTime ?? 0
                self?.isPlaying = false
            }
        }
    }

    private func removeObservers() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    func togglePlay() {
        guard let player else {
            if let entry { load(entry: entry, autoplay: true) }
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func seek(to seconds: TimeInterval) {
        guard let player else { return }
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
    }

    func stop() {
        removeObservers()
        player?.removeAllItems()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        // Deliberately leave the AVAudioSession alone here so an athkar page
        // that was previously playing keeps its route.
    }
}

// MARK: - Header bar UI (compact card, play/pause + seek)

/// Compact header audio card, Arabic-first, matching HomeView card styling.
struct HeaderAudioBar: View {
    @StateObject private var player = HeaderAudioPlayer()
    @State private var entry: HeaderAudioEntry?
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        if let entry, player.hasFile {
            HStack(spacing: 12) {
                Button {
                    player.togglePlay()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.accent)
                        .accessibilityLabel(player.isPlaying ? DikhrStrings.tr("إيقاف مؤقت", "Pause") : DikhrStrings.tr("تشغيل", "Play"))
                }
                .buttonStyle(.borderless)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(DikhrStrings.tr("تلاوة اليوم", "Recitation of the Day"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if player.duration > 0 {
                    VStack(spacing: 2) {
                        Slider(
                            value: Binding(
                                get: { player.currentTime },
                                set: { player.seek(to: $0) }),
                            in: 0...player.duration)
                            .tint(.accent)
                        HStack {
                            Text(format(player.currentTime))
                            Spacer()
                            Text(format(player.duration))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                    .frame(maxWidth: 130)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemGroupedBackground)))
            .onAppear {
                if let today = HeaderAudioSchedule.currentEntry() {
                    self.entry = today
                    player.prepare(entry: today)  // preview only; tap to play
                }
            }
            .onReceive(timer) { _ in
                guard let today = HeaderAudioSchedule.currentEntry(), today != self.entry else { return }
                self.entry = today
                player.stop()
                player.prepare(entry: today)
            }
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(max(0, t))
        let m = total / 60, s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
import Foundation
import AVFoundation
import SwiftUI
import UIKit

// MARK: - Listening playback + controls (self-contained)
//
// The original's AthkarListeningView keeps a persistent audio session and
// continues a category's recitation playlist while navigating / in background
// ("متابعة الاستماع"). Dikhr's AthkarListeningView already plays entries
// sequentially through AudioManager but has no progress/seek bar, no prev/next
// and no background-keep-alive. This file adds those as a self-contained
// component: `ListeningPlayer` mirrors AudioManager's
// configure/play(at:)/togglePlay/stop API (so the listening view can adopt it
// as a near drop-in) and the `ListeningControlsBar` view renders
// progress + prev/next/pause.

@MainActor
final class ListeningPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentIndex = 0
    @Published var entries: [AthkarEntry] = []
    @Published var missingFiles = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVQueuePlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    static var recitationsDirectory: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DikhrShared.appGroupID)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Recitations", isDirectory: true)
    }

    // MARK: Session configuration

    func configure(entries: [AthkarEntry]) {
        self.entries = entries
        currentIndex = 0
    }

    static let audioExtensions = ["mp3", "m4a", "aac"]

    func fileURL(for entry: AthkarEntry) -> URL? {
        guard var audio = entry.Audio, !audio.isEmpty else { return nil }
        for ext in ListeningPlayer.audioExtensions {
            let url = ListeningPlayer.recitationsDirectory
                .appendingPathComponent(audio + "." + ext)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        if (audio as NSString).pathExtension.isEmpty {
            for ext in ListeningPlayer.audioExtensions {
                if let bundled = Bundle.main.url(forResource: audio, withExtension: ext) {
                    return bundled
                }
            }
        } else {
            let ext = (audio as NSString).pathExtension
            let base = (audio as NSString).deletingPathExtension
            if let bundled = Bundle.main.url(forResource: base, withExtension: ext) {
                return bundled
            }
        }
        return nil
    }

    // MARK: Playback

    func play(at index: Int) {
        guard entries.indices.contains(index) else {
            stop()
            return
        }
        guard let url = fileURL(for: entries[index]) else {
            missingFiles += 1
            if index + 1 < entries.count {
                play(at: index + 1)
            } else {
                stop()
            }
            return
        }
        if AVAudioSession.sharedInstance().category != .playback {
            // Persistent spokenAudio session so background navigation pages
            // don't tear the route down.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try? AVAudioSession.sharedInstance().setActive(true)
        }

        rebuildObservers(url: url)
        currentIndex = index
        player?.play()
        isPlaying = true
    }

    private func rebuildObservers(url: URL) {
        removeObservers()
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(items: [item])
        player = queuePlayer
        timeObserver = queuePlayer.addPeriodicTimeObserver(
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
                self?.advance(auto: true)
            }
        }
    }

    private func removeObservers() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        timeObserver = nil
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        endObserver = nil
        player?.removeAllItems()
        player = nil
    }

    func togglePlay() {
        guard let player else {
            play(at: currentIndex)
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
            currentTime = player.currentTime().seconds
        } else if player.currentTime() > .zero {
            player.play()
            isPlaying = true
        } else {
            play(at: currentIndex)
        }
    }

    func advance(auto: Bool = false) {
        // Auto-advance honors the "التالي تلقائيًا" toggle ("listeningAutoAdvance",
        // default ON to preserve existing behavior); the manual next button
        // calls advance() directly and is unaffected.
        if auto && !Self.autoAdvanceOn {
            stop()
            return
        }
        let next = currentIndex + 1
        guard next < entries.count else {
            stop()
            return
        }
        play(at: next)
    }

    // MARK: Auto-advance toggle ("التالي تلقائيًا")
    // Original evidence: 'التالي' => 'Next' + 'Auto' keys in Localizable.strings.

    private static let autoAdvanceKey = "listeningAutoAdvance"

    static var autoAdvanceOn: Bool {
        let d = DikhrShared.defaults
        return d.object(forKey: autoAdvanceKey) == nil ? true : d.bool(forKey: autoAdvanceKey)
    }

    static func setAutoAdvance(_ on: Bool) {
        DikhrShared.defaults.set(on, forKey: autoAdvanceKey)
    }

    /// Play the previous entry, or restart the current one at its beginning.
    func goBack() {
        if player != nil && currentTime > 3 {
            seek(to: 0)
        } else if currentIndex > 0 {
            play(at: currentIndex - 1)
        } else {
            seek(to: 0)
        }
    }

    /// Play the next entry if any.
    func goForward() {
        guard currentIndex + 1 < entries.count else { return }
        play(at: currentIndex + 1)
    }

    func seek(to seconds: TimeInterval) {
        guard let player else { return }
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
    }

    func stop() {
        removeObservers()
        endBackgroundTask()
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    // MARK: Background playback

    /// Playback category alone keeps audio alive in background — but only with
    /// the audio background mode granted. As belt-and-braces for transitions,
    /// hold a UIApplication background task while playing in the background.
    static func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func handleDidEnterBackground() {
        guard isPlaying, backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: "ListeningPlayback"
        ) { [weak self] in
            MainActor.assumeIsolated {
                self?.endBackgroundTask()
            }
        }
    }

    func handleWillEnterForeground() {
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

// MARK: - Controls bar (progress + prev/next/pause)

/// Progress + prev/next/pause bar for the athkar listening page.
/// Arabic labels follow the original strings ("استماع", "متابعة الاستماع").
struct ListeningControlsBar: View {
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject var player: ListeningPlayer

    var body: some View {
        VStack(spacing: 8) {
            progressSection
            controlsRow
            Toggle(
                settings.t("التالي تلقائيًا", "Auto-Play Next"),
                isOn: Binding(
                    get: { ListeningPlayer.autoAdvanceOn },
                    set: { ListeningPlayer.setAutoAdvance($0) }))
                .font(.footnote)
                .tint(.accent)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 24)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    private var controlsRow: some View {
        HStack(spacing: 28) {
                Button {
                    player.goBack()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .foregroundStyle(.accent)
                }
                .buttonStyle(.borderless)
                .disabled(player.entries.isEmpty)
                .accessibilityLabel(settings.t("السابق", "Previous"))

                Button {
                    player.togglePlay()
                } label: {
                    Image(systemName: playIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(.accent)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(player.isPlaying ? settings.t("إيقاف مؤقت", "Pause") : settings.t("تشغيل", "Play"))

                Button {
                    player.goForward()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .foregroundStyle(.accent)
                }
                .buttonStyle(.borderless)
                .disabled(player.currentIndex + 1 >= player.entries.count)
                .accessibilityLabel(settings.t("التالي", "Next"))
            }
    }

    private var playIcon: String {
        player.isPlaying ? "pause.circle.fill" : "play.circle.fill"
    }

    @ViewBuilder
    private var progressSection: some View {
        if player.duration > 0 {
            // Remaining-time label follows the original's on-bar progress
            // readout ("المتبقي: m:ss").
            HStack(spacing: 8) {
                Text(String(format: settings.t("المتبقي: %@", "Remaining: %@"),
                            format(max(0, player.duration - player.currentTime))))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
            }
            HStack(spacing: 10) {
                Text(format(player.currentTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }),
                    in: 0...player.duration)
                    .tint(.accent)
                Text(format(player.duration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(max(0, t))
        let m = total / 60, s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
import Foundation
import AVFoundation
import Combine

/// Recitation playback for athkar pages (AVQueuePlayer + end-of-item观察 through
/// NotificationCenter; no AVAudioPlayerDelegate on this MainActor type, which
/// triggered a stack-guard crash in the simulator).
@MainActor
final class AudioManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentIndex = 0
    @Published var entries: [AthkarEntry] = []
    @Published var missingFiles = 0

    private var player: AVQueuePlayer?
    private var endObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    static var recitationsDirectory: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DikhrShared.appGroupID)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Recitations", isDirectory: true)
    }

    func configure(entries: [AthkarEntry]) {
        self.entries = entries
        currentIndex = 0
    }

    static let audioExtensions = ["mp3", "m4a", "aac"]

    func fileURL(for entry: AthkarEntry) -> URL? {
        guard var audio = entry.Audio, !audio.isEmpty else { return nil }
        // Original stores audio without extension; try the common formats.
        for ext in AudioManager.audioExtensions {
            let url = AudioManager.recitationsDirectory
                .appendingPathComponent(audio + "." + ext)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        if (audio as NSString).pathExtension.isEmpty {
            for ext in AudioManager.audioExtensions {
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
        teardownPlayer()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(items: [item])
        installEndObserver(for: item)
        player = queuePlayer
        queuePlayer.play()
        currentIndex = index
        isPlaying = true
    }

    private func installEndObserver(for item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.advance()
            }
        }
    }

    func togglePlay() {
        guard let player else {
            play(at: currentIndex)
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else if player.currentTime() > .zero {
            player.play()
            isPlaying = true
        } else {
            play(at: currentIndex)
        }
    }

    func advance() {
        let next = currentIndex + 1
        guard next < entries.count else {
            stop()
            return
        }
        play(at: next)
    }

    func stop() {
        teardownPlayer()
        isPlaying = false
    }

    private func teardownPlayer() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        player?.removeAllItems()
        player = nil
    }
}
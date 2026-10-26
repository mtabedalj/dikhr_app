import SwiftUI
import UIKit
import AVFoundation
import AlarmKit

/// Settings row for the AlarmKit-backed athan alarm (the original's
/// "منبه الأذان"):
/// - a global toggle "أذان صامت-حتى-صامت (منبه حقيقي)" that routes the enabled
///   per-prayer athan alarms through the real device alarm system,
/// - the alarm authorization state button (mirrors the original's
///   "Open device Settings → enable «Alarms»" hint),
/// - a test button "جرّب الأذان الآن" that plays the full selected athan file
///   immediately in-app (AVPlayer, full length — unlike the short preview).
struct AthanAlarmToggleRow: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var enabled = AthanAlarmController.isEnabled
    @State private var authState: AlarmManager.AuthorizationState?
    @StateObject private var fullPlayer = AthanFullTestPlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.t("أذان صامت-حتى-صامت (منبه حقيقي)", "Silent-Proof Alarms (Real Alarm)"))
                        .font(.headline)
                    Text(settings.t("منبه الأذان يعمل تلقائيًا حتى لو كان الجهاز في وضع الصامت. يمكنك ضبط المنبه قبل أو بعد الأذان لكل صلاة. يتطلب iOS 26 أو أحدث.",
                                    "The adhan alarm rings through Silent Mode. Alarm offsets before or after adhan are set per prayer. Requires iOS 26 or later."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .onChange(of: enabled) { _, newValue in
                        Task { await apply(newValue) }
                    }
            }

            authorizationBlock()

            Button {
                if fullPlayer.isPlaying {
                    fullPlayer.stop()
                } else {
                    fullPlayer.play(AthanSoundStore.selected(for: "fajr"))
                }
            } label: {
                Label(fullPlayer.isPlaying ? settings.t("إيقاف المعاينة", "Stop Preview") : settings.t("جرّب الأذان الآن", "Try the Adhan Now"),
                      systemImage: fullPlayer.isPlaying ? "stop.circle" : "play.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .disabled(!fullPlayer.hasPlayableSource)
        }
        .padding(.vertical, 2)
        .onAppear {
            authState = AthanAlarmController.authorizationState()
        }
        .onDisappear {
            fullPlayer.stop()
        }
    }

    // MARK: Authorization

    @ViewBuilder
    private func authorizationBlock() -> some View {
        switch authState {
        case .authorized:
            Label(settings.t("المنبهات مفعلة", "Alarms enabled"), systemImage: "bell.badge.fill")
                .foregroundStyle(Color.accentColor)
        case .denied:
            VStack(alignment: .leading, spacing: 6) {
                Label(settings.t("يلزم السماح بالمنبهات", "Alarms permission required"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(settings.t("افتح إعدادات الجهاز ← فعّل \"المنبهات\" حتى يعمل المنبه.",
                                "Open system Settings and enable \"Alarms\" for the alarm to work."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(settings.t("فتح إعدادات الجهاز", "Open System Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        case .notDetermined:
            Button(settings.t("فعّل المنبهات لتطبيق أذكار في إعدادات الجهاز.", "Enable Alarms for Dikhr in system Settings.")) {
                Task {
                    await AthanAlarmController.requestAuthorization()
                    authState = AthanAlarmController.authorizationState()
                    await apply(true)
                }
            }
        case nil:
            Label(settings.t("منبهات الجهاز غير متاحة على هذا الجهاز", "Device alarms are unavailable on this device"), systemImage: "bell.slash")
                .foregroundStyle(.secondary)
        @unknown default:
            EmptyView()
        }
    }

    // MARK: Apply

    private func apply(_ newValue: Bool) async {
        AthanAlarmController.isEnabled = newValue
        await AthanAlarmController.rescheduleAll(
            configs: AlarmScheduler.loadConfigs(),
            method: SettingsStore.loadMethods().first(where: { $0.id == settings.methodID })
                ?? PrayerMethod(fajrAngle: 18.5, ishaAngle: 0, ishaInterval: 90, name: "", params: "ummAlQura"),
            city: settings.currentCity)
    }
}

// MARK: - Full athan test playback

/// Plays the selected athan at full, uninterrupted length (the notification
/// preview is capped at 30 s — this uses AVPlayer with the `.playback`
/// session so the whole file plays, matching the original's "اسمع الأذان كاملًا").
@MainActor
final class AthanFullTestPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    /// Whether the current selection resolves to any playable file.
    var hasPlayableSource: Bool {
        resolveURL(AthanSoundStore.selected(for: "fajr")) != nil
    }

    func play(_ sound: AthanSoundStore.Sound) {
        stop()
        guard let url = resolveURL(sound) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
            }
        }
        player.play()
        isPlaying = true
    }

    func stop() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
    }

    /// Resolve the sound to a URL in the app bundle or Library/Sounds.
    /// With no explicit sound chosen, fall back to the bundled full athan
    /// (athanFull.m4a), covering "أذان كامل".
    private func resolveURL(_ sound: AthanSoundStore.Sound) -> URL? {
        guard let file = sound.fileBaseName else {
            if let full = Bundle.main.url(forResource: "athanFull", withExtension: "m4a") {
                return full
            }
            return nil
        }
        let ext = (file as NSString).pathExtension
        let base = (file as NSString).deletingPathExtension
        if let bundled = Bundle.main.url(forResource: base, withExtension: ext) {
            return bundled
        }
        let local = AthanSoundStore.librarySoundsDirectory().appendingPathComponent(file)
        if FileManager.default.fileExists(atPath: local.path) {
            return local
        }
        return nil
    }
}

/// Full-length playback helper for `AthanSoundStore.Sound`, mirroring the
/// ListeningPlayer pattern (session configured on play, end-notification to
/// reset). Kept in one place so the picker can reuse it later.
extension AthanSoundStore {
    /// Plays the whole file for the given sound; returns the player (already
    /// started) or nil when the sound has no file to play.
    @MainActor
    @discardableResult
    static func playFull(_ sound: Sound, player: AthanFullTestPlayer) -> Bool {
        player.play(sound)
        return player.isPlaying
    }
}
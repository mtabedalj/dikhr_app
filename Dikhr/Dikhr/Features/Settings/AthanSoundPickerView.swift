import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Per-prayer athan sound picker, mirroring the original's "أذان" screens:
/// - the FULL part-track catalog ("جزء من الأذان - …"), free, download-on-tap
/// - the FULL athan alarms ("أذان كامل - …") from the original's CDN
///   (https://athkarapp.com/app/pro/athan/alarms/) — gated to Pro
///   ("الأذان الكامل (منبه حقيقي) — النسخة الاحترافية")
/// - the synthesized built-in chimes under "نغمات مدمجة"
/// - imported Files audio + the optional external-URL downloader
/// Catalog tracks are managed by AthanTrackStore (downloads into
/// Library/Sounds) and mirrored into AthanSoundStore so the notification and
/// AlarmKit paths keep working unchanged.
struct AthanSoundPickerView: View {
    let prayer: String
    let prayerTitle: String

    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var pro = ProStore.shared
    @State private var selection: AthanSoundStore.Sound = .defaultSystem
    @State private var selectedTrackKey: String?
    @State private var builtins: [AthanSoundStore.Sound] = []
    @State private var imported: [AthanSoundStore.Sound] = []
    @State private var showImporter = false
    @State private var previewPlayer: AVAPlayerBox?
    @State private var status: String?
    @State private var downloadURLText: String
    @State private var downloading = false
    @State private var downloadingTrackKey: String?

    init(prayer: String, prayerTitle: String) {
        self.prayer = prayer
        self.prayerTitle = prayerTitle
        _downloadURLText = State(initialValue: DikhrShared.defaults.string(forKey: "athanSourceURL") ?? "")
    }

    var body: some View {
        Form {
            Section(settings.t("الصوت — منبه \(prayerTitle)", "Sound — \(prayerTitle) alarm")) {
                row(.defaultSystem)
                row(.silent)
            }

            PartCatalogSection

            FullCatalogSection

            builtinsSection

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label(settings.t("استيراد من الملفات", "Import from Files"), systemImage: "folder.badge.plus")
                }
                if selection.notificationSafe == false, selectedTrackKey == nil {
                    Label(settings.t("هذا الصوت يعمل كمعاينة فقط؛ ملفات التنبيه يجب أن تكون caf/aiff/wav", "This sound works for preview only; alert files must be caf/aiff/wav"), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                TextField(settings.t("رابط ملف صوتي مباشر", "Direct audio file URL"), text: $downloadURLText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await download() }
                } label: {
                    if downloading {
                        ProgressView()
                    } else {
                        Label(settings.t("تنزيل وتثبيت", "Download & Install"), systemImage: "arrow.down.circle")
                    }
                }
                .disabled(downloading || downloadURLText.isEmpty)
            } header: {
                Text(settings.t("تنزيل من مصدر خارجي (اختياري)", "Download from External Source (Optional)"))
            } footer: {
                Text(settings.t("مثل ميزة إعادة تنزيل الأذان في التطبيق الأصلي", "Like the adhan re-download feature in the original app"))
            }
            if let status {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(settings.t("صوت الأذان", "Adhan Sound"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
        .onDisappear {
            previewPlayer = nil
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.audio],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    do {
                        let sound = try await AthanSoundStore.importSound(from: url)
                        AthanSoundStore.setSelected(sound, for: prayer)
                        AthanTrackStore.clearSelection(for: prayer)
                        imported = importedSoundsFiltered()
                        selection = sound
                        selectedTrackKey = nil
                        status = "\(settings.t("تم الاستيراد", "Imported")): \(sound.label)"
                    } catch {
                        status = "\(settings.t("فشل الاستيراد", "Import failed")): \(error.localizedDescription)"
                    }
                }
            case .failure(let error):
                status = error.localizedDescription
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var PartCatalogSection: some View {
        Section {
            ForEach(AthanTracksCatalog.parts) { track in
                catalogRow(track)
            }
        } header: {
            Text(settings.t("جزء من الأذان", "Part of the Athan"))
        } footer: {
            Text(settings.t("لا يوجد حاليًا الأذان كاملًا كصوت إشعار لأن التنبيه في أجهزة أبل محدود بــ 30 ثانية فقط، للاستماع إلى الأذان كاملًا استخدم قسم \"الأذان الكامل\" مع منبه الأذان.", "Notification sounds are capped at 30 seconds on Apple devices; use the “Full Athan” section with the Athan alarm to hear the full adhan."))
        }
    }

    @ViewBuilder
    private var FullCatalogSection: some View {
        Section {
            ForEach(AthanTracksCatalog.full) { track in
                if pro.isPro {
                    catalogRow(track)
                } else {
                    NavigationLink {
                        ProPayView()
                    } label: {
                        lockedFullRow(track)
                    }
                }
            }
        } header: {
            Text(settings.t("الأذان الكامل (منبه حقيقي) — النسخة الاحترافية", "Full Athan (real alarm) — Pro Edition"))
        } footer: {
            Text(settings.t("منبه يعمل حتى في وضع الصامت: يُشغّل الأذان كاملًا من عدة مؤذنين. متاح للمشتركين فقط.", "A real alarm that plays even on silent: the full adhan from several muezzins. Pro subscribers only."))
        }
    }

    @ViewBuilder
    private var builtinsSection: some View {
        Section {
            ForEach(builtins) { sound in
                row(sound)
            }
            ForEach(imported) { sound in
                row(sound, allowPreview: true)
            }
        } header: {
            Text(settings.t("نغمات مدمجة", "Built-in Chimes"))
        }
    }

    // MARK: - Rows

    private func row(_ sound: AthanSoundStore.Sound, allowPreview: Bool = true) -> some View {
        Button {
            selection = sound
            selectedTrackKey = nil
            AthanTrackStore.clearSelection(for: prayer)
            AthanSoundStore.setSelected(sound, for: prayer)
            status = "\(settings.t("تم الاختيار", "Selected")): \(sound.label)"
        } label: {
            HStack {
                Text(sound.label)
                    .foregroundStyle(.primary)
                Spacer()
                if allowPreview, sound.fileBaseName != nil {
                    Button {
                        previewPlayer = AVAPlayerBox(player: AthanSoundStore.preview(sound))
                    } label: {
                        Image(systemName: "waveform.circle")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                }
                if selectedTrackKey == nil,
                   selection == sound {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    /// A catalog track row: Arabic name (primary) + English caption, preview, checkmark.
    @ViewBuilder
    private func catalogRow(_ track: AthanTrack) -> some View {
        Button {
            select(track)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.arabicName)
                        .foregroundStyle(.primary)
                    Text(track.englishName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let downloadingKey = downloadingTrackKey, downloadingKey == track.id {
                    ProgressView()
                        .buttonStyle(.borderless)
                } else if AthanTrackStore.localFileURL(for: track) == nil, track.cdnCounterpart != nil {
                    Button {
                        Task { await downloadTrack(track) }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(settings.t("تنزيل", "Download"))
                } else {
                    Button {
                        previewTrack(track)
                    } label: {
                        Image(systemName: "waveform.circle")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                }
                if selectedTrackKey == track.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    /// Locked full-alarm row (non-Pro): Pro badge, tap pushes the paywall.
    private func lockedFullRow(_ track: AthanTrack) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(track.arabicName)
                    .foregroundStyle(.primary)
                Text(track.englishName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Pro")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.accent.opacity(0.18)))
                .foregroundStyle(.accent)
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func refresh() {
        builtins = AthanSoundStore.builtinSounds()
        imported = importedSoundsFiltered()
        selection = AthanSoundStore.selected(for: prayer)
        selectedTrackKey = AthanTrackStore.selectedKey(for: prayer)
    }

    /// Imported sounds minus the catalog's own downloads (they have their own rows).
    private func importedSoundsFiltered() -> [AthanSoundStore.Sound] {
        AthanSoundStore.importedSounds().filter { sound in
            !(sound.fileBaseName?.hasPrefix(AthanTrackStore.downloadedFilePrefix) ?? true)
        }
    }

    private func select(_ track: AthanTrack) {
        guard AthanTrackStore.localFileURL(for: track) != nil else {
            // Not local: fetch it now (parts are free; full rows are Pro-only).
            Task { await downloadTrack(track) }
            return
        }
        selectedTrackKey = track.key
        AthanTrackStore.setSelected(track, for: prayer)
        if let mirrored = AthanTrackStore.localFileURL(for: track)?.lastPathComponent {
            selection = .imported(mirrored)
        }
        status = "\(settings.t("تم الاختيار", "Selected")): \(track.arabicName)"
    }

    @MainActor
    private func previewTrack(_ track: AthanTrack) {
        guard let url = AthanTrackStore.localFileURL(for: track) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.8
            player.play()
            previewPlayer = AVAPlayerBox(player: player)
        } catch {
            status = "\(settings.t("تعذر تشغيل الصوت", "Playback failed")): \(error.localizedDescription)"
        }
    }

    private func downloadTrack(_ track: AthanTrack) async {
        guard AthanTrackStore.localFileURL(for: track) == nil else {
            select(track)
            return
        }
        guard let _ = track.cdnCounterpart else {
            status = AthanTrackStore.DownloadError.noCounterpart.errorDescription
            return
        }
        if track.section == .full && !pro.isPro { return } // full tracks are Pro-gated
        downloadingTrackKey = track.id
        defer { downloadingTrackKey = nil }
        do {
            let url = try await AthanTrackStore.download(track)
            // AthanTrackStore.setSelected mirrors into AthanSoundStore so the
            // notification path (AlarmScheduler) sees it too.
            AthanTrackStore.setSelected(track, for: prayer)
            selectedTrackKey = track.key
            selection = .imported(url.lastPathComponent)
            status = "\(settings.t("تم التنزيل", "Downloaded")): \(track.arabicName)"
        } catch {
            status = "\(settings.t("فشل التنزيل", "Download failed")): \(error.localizedDescription)"
        }
    }

    // MARK: External-url download (kept from the previous picker structure)

    private func download() async {
        guard let remote = URL(string: downloadURLText.trimmingCharacters(in: .whitespaces)) else {
            status = settings.t("الرابط غير صالح", "Invalid URL")
            return
        }
        DikhrShared.defaults.set(downloadURLText, forKey: "athanSourceURL")
        downloading = true
        defer { downloading = false }
        do {
            let sound = try await AthanSoundStore.downloadSound(from: remote)
            imported = importedSoundsFiltered()
            selection = sound
            AthanTrackStore.clearSelection(for: prayer)
            selectedTrackKey = nil
            AthanSoundStore.setSelected(sound, for: prayer)
            status = "\(settings.t("تم التنزيل والتثبيت", "Downloaded and installed")): \(sound.label)"
        } catch {
            status = "\(settings.t("فشل التنزيل", "Download failed")): \(error.localizedDescription)"
        }
    }
}

/// Boxed player reference to avoid observing AVAudioPlayer directly.
struct AVAPlayerBox {
    var player: AVAudioPlayer?
    init(player: AVAudioPlayer?) {
        self.player = player
    }
}
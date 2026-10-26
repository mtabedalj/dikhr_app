import SwiftUI

/// Sequential recitation listening for a category (like the original's
/// أذكار listening mode). Files are user-supplied in the Recitations folder.
struct AthkarListeningView: View {
    @EnvironmentObject private var settings: SettingsStore
    let category: AthkarCategory
    @StateObject private var audio = ListeningPlayer()

    var body: some View {
        VStack(spacing: 14) {
            ListeningControlsBar(player: audio)
            if audio.missingFiles > 0 && !audio.isPlaying {
                Label(settings.t("ملفات التلاوة غير موجودة — ضعها في مجلد \u{200E}Recitations\u{200F} في تطبيق الملفات (On My iPhone/Dikhr)",
                                 "Recitation files not found — put them in the \u{200E}Recitations\u{200F} folder in the Files app (On My iPhone/Dikhr)"), systemImage: "speaker.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(category.entries.enumerated()), id: \.offset) { index, entry in
                        HStack {
                            Text(entry.Title ?? AthkarStore.htmlToPlain(entry.Athkar ?? ""))
                                .font(.headline)
                                .foregroundStyle(index == audio.currentIndex ? .accent : .primary)
                                .lineLimit(2)
                            Spacer()
                            Button {
                                audio.play(at: index)
                            } label: {
                                Image(systemName: index == audio.currentIndex && audio.isPlaying
                                      ? "waveform.circle.fill" : "play.circle")
                                    .font(.title2)
                                    .foregroundStyle(.accent)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(settings.t("استماع: \(category.title)",
                                    "Listen: \(category.localizedTitle(settings.lang))"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            audio.configure(entries: category.entries)
            if ProcessInfo.processInfo.environment["DIKHR_AUTOPLAY"] != nil && !audio.isPlaying {
                audio.play(at: 0)
            }
        }
        .onDisappear { audio.stop() }
    }
}
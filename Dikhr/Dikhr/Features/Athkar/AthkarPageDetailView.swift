import SwiftUI

// MARK: - Athkar category detail page (rebuilt from live captures)
//
// /tmp/athkar_morning2.png — MODE 1 single zikr: black page, centered page
// title, round back chevron top-right, TWO round toolbar buttons top-left
// (list toggle ⋲ + notes toggle ▤), thin blue gradient hairline under the
// toolbar, large white Uthmanic zikr with an ornate circled segment-count
// marker at its end (the dhikr's repeat target, e.g. ١٠٠), the source notes
// BELOW in blue (the span/h3 accent #0aa3c8), centered, and a bottom bar:
// "1|25" outside the bar at its left end, then a dark capsule with the
// favorite star at the left end and play + share at the right end.
//
// /tmp/am_play.png — MODE 2 list (toggled by the ⋲ button): vertical scroll of
// rounded dark cards; each card shows the zikr with circled ①②③ markers at the
// segment boundaries, a footer (RTL: play circle at the RIGHT end, then the
// gray title, then white "n|25", and at the card's LEFT end a count badge —
// a circle with the tap count, gold partial arc while below the entry's
// target, full gold ring once complete). The most recently tapped card gets a
// GOLD border.
//
// /tmp/am_notes.png — the ▤ button HIDES the blue note segments (all text
// turns white); tapping it again restores them. Counts persist per day
// (DikhrShared app-group, key athkar_zikr_counts_<yyyy-MM-dd>) and every tap
// feeds the existing StreaksStore daily athkar counter.

/// Arabic-Indic digits (٠١٢٣...) — the original renders numbers in Arabic
/// script inside every ornament/badge.
func athkarArabicDigits(_ n: Int) -> String {
    let arabic = "٠١٢٣٤٥٦٧٨٩"
    return String(n).compactMap { c in
        guard let d = c.wholeNumberValue, (0...9).contains(d) else { return nil }
        return arabic[arabic.index(arabic.startIndex, offsetBy: d)].description
    }.joined()
}

/// Ornate circled number: thin stroke circle + Arabic-Indic digits (white),
/// used for the segment-boundary markers and the repeat-target marker.
struct AthkarCircledNumber: View {
    var value: Int
    var diameter: CGFloat = 24
    var color: Color = .white

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.9), lineWidth: 1.2)
            Text(athkarArabicDigits(value))
                .font(.system(size: diameter * 0.42, weight: .light))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 2)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Per-entry daily tap counts (app-group persistence)

/// Counts persist per day, keyed per category+entry, in the DikhrShared app
/// group under `athkar_zikr_counts_<yyyy-MM-dd>` (a [key: count] JSON dict).
/// Old days' keys simply stop being read. Every tap also feeds the existing
/// StreaksStore daily model (athkarCount → مداومة streaks).
@MainActor
final class AthkarZikrCountStore: ObservableObject {
    static let keyPrefix = "athkar_zikr_counts_"

    @Published private(set) var counts: [String: Int] = [:]

    private static func dayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return keyPrefix + f.string(from: Date())
    }

    func load() {
        let key = Self.dayKey()
        if let data = DikhrShared.defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            counts = decoded
        } else {
            counts = [:]
        }
    }

    func count(for key: String) -> Int { counts[key] ?? 0 }

    func increment(for key: String) {
        counts[key, default: 0] += 1
        if let data = try? JSONEncoder().encode(counts) {
            DikhrShared.defaults.set(data, forKey: Self.dayKey())
        }
    }
}

// MARK: - Detail page

struct AthkarPageDetailView: View {
    let category: AthkarCategory

    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audio = AudioManager()
    @StateObject private var counts = AthkarZikrCountStore()
    @State private var listMode = false
    @State private var notesShown = true
    @State private var index = 0
    @State private var lastTapped: String?
    @State private var listening = false

    private var entries: [AthkarEntry] { category.entries }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                chrome
                hairline
                if listMode {
                    listContent
                } else {
                    singleContent
                    singleBottomBar
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if entries.indices.contains(index) == false { index = 0 }
            audio.configure(entries: entries)
            counts.load()
            if ProcessInfo.processInfo.environment["DIKHTML_LISTEN"] != nil ||
               ProcessInfo.processInfo.environment["DIKHR_LISTEN"] != nil {
                listening = true
            }
        }
        .sheet(isPresented: $listening) {
            AthkarListeningView(category: category)
        }
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            audio.stop()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(0.09)))
        }
        .buttonStyle(.plain)
    }

    // MARK: chrome (title centered, back chevron right, toggles left)

    private var chrome: some View {
        ZStack {
            // Bilingual page title.
            Text(category.localizedTitle(settings.lang))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 10) {
                // RTL: first child sits at the RIGHT — the back chevron
                // (points right in RTL, like the capture).
                circleButton("chevron.backward", action: { dismiss() })
                Spacer()
                // Trailing-side pair; RTL order → visual left-to-right is
                // list (leftmost) then notes — matching the capture.
                circleButton("doc.text", action: { notesShown.toggle() })
                circleButton("list.bullet", action: { withAnimation(.easeInOut(duration: 0.2)) { listMode.toggle() } })
            }
            .padding(.leading, 18)
            .padding(.trailing, 18)
        }
        .padding(.top, 34)
        .padding(.bottom, 12)
    }

    private var hairline: some View {
        LinearGradient(colors: [.clear,
                                Color(red: 0.04, green: 0.64, blue: 0.78), // #0aa3c8
                                .clear],
                       startPoint: .leading, endPoint: .trailing)
            .frame(height: 1.5)
            .padding(.horizontal, 22)
            .padding(.bottom, 4)
    }

    // MARK: shared entry text rendering

    private func isNote(_ style: AthkarTextRenderer.SegmentStyle) -> Bool {
        style == .note || style == .attribution
    }

    private func displaySegments(_ entry: AthkarEntry) -> [AthkarTextRenderer.Segment] {
        AthkarTextRenderer.segments(entry.Athkar ?? "").filter { seg in
            notesShown || !isNote(seg.style)
        }
    }

    private var noteAccent: Color {
        // The span-notes accent: dark #003976, dark-mode #0aa3c8 — this page
        // is always dark.
        Color(red: 10 / 255, green: 163 / 255, blue: 200 / 255)
    }

    private var gold: Color {
        Color(red: 0.79, green: 0.65, blue: 0.35)
    }

    private func segmentText(_ segment: AthkarTextRenderer.Segment, big: Bool) -> AnyView {
        if big {
            return AnyView(Text(segment.text)
                .font(.custom("KFGQPCHAFSUthmanicScript-Bold", size: 27))
                .foregroundStyle(.white)
                .lineSpacing(14))
        }
        switch segment.style {
        case .note, .attribution:
            return AnyView(Text(segment.text)
                .font(.athkarBody)
                .foregroundStyle(noteAccent)
                .lineSpacing(8))
        case .heading:
            return AnyView(Text(segment.text)
                .font(.athkarBody.weight(.semibold))
                .foregroundStyle(noteAccent)
                .lineSpacing(8))
        case .quran, .body:
            return AnyView(Text(segment.text)
                .font(.athkarBody)
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(8))
        }
    }

    // MARK: MODE 1 — single zikr carousel

    private var singleContent: some View {
        ZStack(alignment: .bottom) {
            // RTL paging: first entry leads on the right.
            TabView(selection: $index) {
                ForEach(Array(entries.enumerated()), id: \.offset) { i, _ in
                    singleEntry(i)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: index) { _, _ in audio.stop() }
        }
    }

    private func singleEntry(_ i: Int) -> some View {
        let entry = entries[max(0, min(i, max(0, entries.count - 1)))]
        let segments = displaySegments(entry)
        let main = segments.filter { !isNote($0.style) && $0.style != .heading }
        let notes = segments.filter { isNote($0.style) || $0.style == .heading }
        let target = max(0, entry.Count ?? 0)

        return ScrollView {
            VStack(spacing: 20) {
                // Zikr in LARGE white Uthmanic, with the ornate circled
                // repeat-target marker (e.g. ١٠٠) at its end.
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(main) { seg in
                        segmentText(seg, big: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    if target > 1 {
                        HStack {
                            Spacer()
                            AthkarCircledNumber(value: target, diameter: 40)
                        }
                    }
                }
                // Source notes BELOW the zikr, blue, centered.
                if !notes.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(notes) { seg in
                            segmentText(seg, big: false)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 26)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            // Tap advances to the next zikr (like the original).
            .contentShape(Rectangle())
            .onTapGesture {
                if entries.count > 1 {
                    withAnimation { index = (index + 1) % entries.count }
                }
            }
        }
    }

    /// "1|25" outside the bar (left end, RTL), then the dark capsule:
    /// share + play at the RIGHT end, favorite star at the LEFT end.
    private var singleBottomBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(index + 1)|\(entries.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 20)
            bottomBar
        }
        .padding(.bottom, 8)
    }

    private var bottomBar: some View {
        let entry = entries.indices.contains(index) ? entries[index] : nil
        return HStack(spacing: 12) {
            // RTL: first child = rightmost → share, then play, then the
            // favorite star at the left end.
            if let entry {
                ShareLink(item: entryShareText(entry)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.09)))
                }
                playButton(entry: entry, size: 44, iconSize: 15)
                Spacer()
                starButton(entry: entry)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 30)
            .fill(Color(white: 0.07)))
        .padding(.horizontal, 14)
    }

    private func playButton(entry: AthkarEntry, size: CGFloat, iconSize: CGFloat) -> some View {
        let playing = audio.isPlaying && audio.currentIndex == entries.firstIndex(of: entry)
        return Button {
            if playing {
                audio.stop()
            } else if let i = entries.firstIndex(of: entry) {
                audio.play(at: i)
            }
        } label: {
            Image(systemName: playing ? "pause.fill" : "play.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(0.09)))
        }
        .opacity(AudioManager.fileURLExists(for: entry) ? 1 : 0.35)
    }

    private func starButton(entry: AthkarEntry) -> some View {
        let key = athkarDetailKey(category, entry)
        return Button {
            if settings.favorites.contains(key) {
                settings.favorites.remove(key)
            } else {
                settings.favorites.insert(key)
            }
        } label: {
            Image(systemName: settings.favorites.contains(key) ? "star.fill" : "star")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(settings.favorites.contains(key) ? gold : .white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.09)))
        }
        .buttonStyle(.plain)
    }

    private func entryShareText(_ entry: AthkarEntry) -> String {
        var parts: [String] = []
        if let title = entry.Title, !title.isEmpty { parts.append(title) }
        let body = AthkarStore.stripHTML(entry.Athkar ?? "")
        if !body.isEmpty { parts.append(body) }
        return parts.joined(separator: "\n\n")
    }

    // MARK: MODE 2 — list cards with tap-to-count

    private var listContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(Array(entries.enumerated()), id: \.offset) { i, entry in
                    let key = athkarDetailKey(category, entry)
                    listCard(entry: entry,
                             index: i,
                             key: key,
                             count: counts.count(for: key),
                             target: max(1, entry.Count ?? 1),
                             isLastTapped: lastTapped == key)
                        .id(i)
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .padding(.top, 4)
    }

    private func listCard(entry: AthkarEntry, index: Int, key: String,
                          count: Int, target: Int, isLastTapped: Bool) -> some View {
        let segments = displaySegments(entry)
        return VStack(alignment: .leading, spacing: 16) {
            // Zikr with circled ①②③ markers at the segment boundaries.
            VStack(alignment: .leading, spacing: 12) {
                ForEach(segments) { seg in
                    HStack(alignment: .center, spacing: 8) {
                        if seg.id > 0 {
                            AthkarCircledNumber(value: seg.id, diameter: 21)
                        }
                        segmentText(seg, big: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            // Footer (RTL): play circle at the RIGHT end, gray title, white
            // "n|total", and the tap-count badge at the card's LEFT end.
            HStack(alignment: .center, spacing: 8) {
                playButton(entry: entry, size: 34, iconSize: 11).id("play-\(index)")
                if let title = entry.Title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text("\(index + 1)|\(entries.count)")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Spacer()
                countBadge(count: count, target: target)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 26)
            .fill(Color(red: 0.055, green: 0.055, blue: 0.062)))
        .overlay(RoundedRectangle(cornerRadius: 26)
            .stroke(isLastTapped ? gold : Color.white.opacity(0.08),
                    lineWidth: isLastTapped ? 2 : 1))
        .contentShape(Rectangle())
        // Tap ANYWHERE on the card increments the count.
        .onTapGesture {
            counts.increment(for: key)
            StreaksStore.addAthkar(1)
            withAnimation(.easeInOut(duration: 0.15)) {
                lastTapped = key
            }
        }
    }

    /// Count badge: plain circle with the tap count (Arabic digits); a gold
    /// partial arc while below the entry's target, a FULL gold ring once
    /// count == target.
    private func countBadge(count: Int, target: Int) -> some View {
        let ratio = target > 0 ? Double(min(count, target)) / Double(target) : 0
        return ZStack {
            Circle().stroke(Color.white.opacity(0.22), lineWidth: 2.5)
            if ratio > 0 {
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(gold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text(athkarArabicDigits(count))
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: 38, height: 38)
    }
}

// MARK: - Entry key (same identity scheme as favorites)

/// Favorite/count identity: "categoryId|Title" (or the stripped-text prefix
/// for untitled entries). Defined file-local in both detail and home files.
private func athkarDetailKey(_ category: AthkarCategory, _ entry: AthkarEntry) -> String {
    let fallback = String(AthkarStore.stripHTML(entry.Athkar ?? "").prefix(24))
    return "\(category.id)|\(entry.Title ?? fallback)"
}

// MARK: - Audio availability probe (cheap, no player allocation)

extension AudioManager {
    /// Whether the entry's audio file resolves (bundled or Recitations), used
    /// only to de-emphasize the play button.
    static func fileURLExists(for entry: AthkarEntry) -> Bool {
        guard var audio = entry.Audio, !audio.isEmpty else { return false }
        for ext in audioExtensions {
            let url = recitationsDirectory.appendingPathComponent(audio + "." + ext)
            if FileManager.default.fileExists(atPath: url.path) { return true }
        }
        if (audio as NSString).pathExtension.isEmpty {
            for ext in audioExtensions {
                if Bundle.main.url(forResource: audio, withExtension: ext) != nil { return true }
            }
        } else {
            let base = (audio as NSString).deletingPathExtension
            let ext = (audio as NSString).pathExtension
            if Bundle.main.url(forResource: base, withExtension: ext) != nil { return true }
        }
        return false
    }
}
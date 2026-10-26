import SwiftUI

// MARK: - Daily ayah card
//
// Original ground truth: the Athkar home/quran header shows a rotating verse
// from Ayaat.json — 182 entries shaped { ayah, surah, page, ayahNumber } where
// "ayah" already carries the ﴿ … ﴾ brackets and "surah" holds e.g. "الضحى ٥"
// (surah name + ayah number). The verse rotates by day.
// Data is baked to Dikhr/Resources/home_ayaat.json (bundle copy of Ayaat.json).

struct DailyAyahEntry: Decodable {
    let ayah: String
    let surah: String
    let page: Int
    let ayahNumber: Int
}

enum DailyAyahStore {
    static func load() -> [DailyAyahEntry] {
        guard let url = Bundle.main.url(forResource: "home_ayaat", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([DailyAyahEntry].self, from: data)
        else { return [] }
        return entries
    }

    /// Stable per-day pick: whole gregorian days since 2001-01-01 modulo count,
    /// so the same verse shows all day and advances each midnight.
    static func index(for now: Date, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let days = Int(now.timeIntervalSince1970) / 86_400 - 11_323
        return ((days % count) + count) % count
    }
}

struct DailyAyahCard: View {
    @State private var now = Date()
    @State private var offset = 0
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let entries = DailyAyahStore.load()

    private var entry: DailyAyahEntry? {
        guard !entries.isEmpty else { return nil }
        let i = (DailyAyahStore.index(for: now, count: entries.count) + offset) % entries.count
        return i >= 0 ? entries[i] : nil
    }

    var body: some View {
        Group {
            if let e = entry {
                VStack(spacing: 8) {
                    Text(verbatim: e.ayah)
                        .font(.quranNaskh)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(QuranPalette.darkGreen)
                    Text(verbatim: "سورة \(e.surah)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
                .contentShape(Rectangle())
                .onTapGesture { withAnimation { offset += 1 } } // tap to see the next verse
            } else {
                EmptyView()
            }
        }
        .onReceive(timer) { now = $0 }
        .dikhrRefresh(now: $now)
    }
}
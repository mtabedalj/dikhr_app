import SwiftUI

// MARK: - أسماء الله الحسنى page (from the athkar home grid)
//
// Evidence: live capture /tmp/athkar_morning.png of the REAL Athkar app:
//   - pure black page, no nav bar
//   - centered bold white title "أسماء الله الحسنى", round right-chevron
//     back button at the top-right (right chevron = back in RTL)
//   - under the title: three dark pill chips (RTL right→left):
//     "في القرآن" / "عرض الأسماء" / "المصحف"
//   - default view: a 6-column grid of rounded dark tiles (corner ~18),
//     flowing RTL (1 at the top-right, 6 top-left, wrapping down), each tile
//     the name in bold Scheherazade-style Arabic centered (wraps to two
//     lines when long) + a small gray number at the bottom-center (1..99
//     in their order).
//
// Chip behaviors (honest, data-derived — the original app's binaries are
// not readable for these):
//   - عرض الأسماء  → the default 99-name grid (capture ground truth).
//   - في القرآن   → grid filtered to the names attested verbatim in the
//     Quran. Dikhr's allahNames data (original content.json) ships only
//     translitered "Details", so the set is derived from Dikhr's own
//     Quran.sqlite: normalized (diacritics stripped, ٱ→ا) whole-token
//     matching of the name — definite-article form or bare participle
//     root with attached و/ب/ل/ف — across text+search_text of every ayah
//     (74/99 verbatim; names that appear only inflected, e.g. المُقِيت
//     from "مُّقِيتًا", do not match verbatim). Baked in
//     Resources/allahNamesQuran-baked.json with the tool script in
//     ../scripts/tmp/anames/.
//   - المصحف     → best-effort substitute: the name list with the shipped
//     transliteration "Details". The original's mushaf-style presentation
//     is not reproducible from the shipped data, so this mode shows the
//     list reading view instead of inventing a mushaf mockup.
//
// The names list and its 1..99 numbering come from
// AthkarStore.loadNinetyNineNames() (original content.json order), which
// is the dataset the capture tiles display (name 1 = "اللَّهُ",
// 6 = "السَّلامُ" — matches the capture exactly).

private let allahNamesTileFill = Color(red: 0.058, green: 0.058, blue: 0.062)
private let allahNamesChipFill = Color.white.opacity(0.10)

enum AllahNamesChip: CaseIterable {
    case quran   // في القرآن
    case names   // عرض الأسماء (default — the capture's grid)
    case mushaf  // المصحف

    var title: (ar: String, en: String) {
        switch self {
        case .quran: return ("في القرآن", "In Quran")
        case .names: return ("عرض الأسماء", "Display names")
        case .mushaf: return ("المصحف", "Mushaf")
        }
    }
}

struct AllahNamesView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var names: [(name: String, details: String)] = []
    @State private var inQuran: Set<String> = []
    @State private var chip: AllahNamesChip = .names
    @State private var query = ""

    // RTL is part of the capture's ground truth (tile 1 top-right), so the
    // page pins it instead of following the app language.

    private var filtered: [(offset: Int, element: (name: String, details: String))] {
        Array(names.enumerated())
            .filter { entry in
                if chip == .quran && !inQuran.contains(entry.element.name) { return false }
                if query.isEmpty { return true }
                return entry.element.name.contains(query)
                    || entry.element.details.localizedCaseInsensitiveContains(query)
            }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)
    }

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.024).ignoresSafeArea()
            VStack(spacing: 12) {
                topBar
                chipRow
                searchField
                switch chip {
                case .names, .quran: nameGrid
                case .mushaf: mushafList
                }
            }
            .padding(.horizontal, 14)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: load)
    }

    private func load() {
        if names.isEmpty {
            names = AthkarStore.loadNinetyNineNames()
            inQuran = AllahNamesData.versifiedNames()
        }
    }

    // MARK: top bar — centered title + round right-chevron back (top-right)

    private var topBar: some View {
        ZStack(alignment: .top) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 52)
            Text(settings.t("أسماء الله الحسنى", "Names of Allah"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 52)
        }
    }

    // MARK: chip row — three dark pills spanning the width (RTL right→left)

    private var chipRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(AllahNamesChip.allCases.enumerated()), id: \.offset) { _, c in
                Button {
                    chip = c
                } label: {
                    Text(settings.t(c.title.ar, c.title.en))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(chip == c ? Color.white : Color.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.white.opacity(chip == c ? 0.16 : 0.10))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: search keeps the original's search function on-page (the
    // original moved its search chrome to its own page; here it filters the
    // grid in place since this page hides the nav bar that hosts .searchable)

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.45))
            TextField(settings.t("ابحث في الأسماء", "Search the names"), text: $query)
                .font(.system(size: 15))
                .foregroundStyle(.white)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    // MARK: 6-column RTL grid — dark rounded tiles, name + gray number

    private var nameGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(filtered, id: \.offset) { entry in
                    tile(entry.element.name, number: entry.offset + 1)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
            if filtered.isEmpty {
                Text(settings.t("لا توجد أسماء مطابقة", "No matching names"))
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 40)
            }
        }
    }

    private func tile(_ name: String, number: Int) -> some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Text(name)
                .font(Font.custom("Scheherazade-Regular", size: 17).weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.4)
            Spacer(minLength: 0)
            Text("\(number)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .background(RoundedRectangle(cornerRadius: 18).fill(allahNamesTileFill))
    }

    // MARK: المصحف mode — honest best-effort: shipped list view
    // (name + transliteration Details) replacing the original's
    // unreproducible mushaf presentation.

    private var mushafList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered, id: \.offset) { entry in
                    HStack {
                        Text("\(entry.offset + 1)")
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.3))
                            .frame(width: 28)
                        Text(entry.element.name)
                            .font(Font.custom("Scheherazade-Regular", size: 20).weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(entry.element.details)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.vertical, 10)
                    .background(Rectangle().fill(allahNamesTileFill))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - data helpers

/// Reads the baked verbatim-in-Quran name set (Resources/allahNamesQuran-baked.json).
enum AllahNamesData {
    static func versifiedNames() -> Set<String> {
        guard let url = Bundle.main.url(forResource: "allahNamesQuran-baked", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = raw["inQuran"] as? [String]
        else { return [] }
        return Set(list)
    }
}
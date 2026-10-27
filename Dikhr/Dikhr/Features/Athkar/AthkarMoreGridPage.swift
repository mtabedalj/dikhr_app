import SwiftUI

// MARK: - المزيد grid (rebuilt from live capture /tmp/w19_prayertab.png)
//
// The real Athkar app's المزيد page (opened from the athkar home's المزيد
// chip): black page, centered bold white title, round right-chevron back
// top-right, a plain search INPUT PILL under the title ("ابحث ..." +
// magnifier at the right end, same shape as the search page's pill but with
// no AI sparkle), then a TWO-COLUMN grid of large rounded situational-dua
// COLLECTION cards. Each card: subtle tinted dark background cycle
// (brown / slate / mauve / olive), bold white RTL right-aligned title.
//
// Ground truth: every captured card title, in order (RTL, first card top-
// right), is exactly Page4's entries in REVERSE index order:
//   صلاة الاستخارة, دعاء السفر, دعاء المسافر للمقيم, دعاء المقيم للمسافر,
//   دعاء سيد الاستغفار, الذكر عند الدخول أو الخروج من المنزل, الذكر عند
//   لبس الثوب, دعاء لبس الثوب الجديد, الدعاء لمن لبس ثوبًا جديدًا, ما يقول
//   إذا وضع الثوب, دعاء الركوب (السيارة وما نحوه), كفارة المجلس, الذكر عند
//   رؤية أهل البلاء, دعاء من استصعب عليه أمر, دعاء الكرب, ...
// The tint pattern follows: odd grid positions (left column) are always the
// slate tone; even positions (right column) cycle brown → mauve → olive.

/// Deterministic card tint palette matching the capture's hues.
private enum MoreCardTint {
    case slate, brown, mauve, olive, plum

    var color: Color {
        switch self {
        case .slate: return Color(red: 0.220, green: 0.235, blue: 0.280)  // cool slate #383C47
        case .brown: return Color(red: 0.255, green: 0.200, blue: 0.215)  // warm brown #413336
        case .mauve: return Color(red: 0.255, green: 0.205, blue: 0.230)  // mauve #41343B
        case .olive: return Color(red: 0.250, green: 0.275, blue: 0.225)  // olive #404639
        case .plum:  return Color(red: 0.245, green: 0.210, blue: 0.235)  // plum #3F353C
        }
    }

    /// Capture's rule: left column (odd index 1,3,5...) always slate; the
    /// right column cycles the warm hues by pair index.
    static func tint(for gridIndex: Int) -> MoreCardTint {
        gridIndex % 2 == 1
            ? .slate
            : [.brown, .mauve, .olive, .plum, .brown, .mauve][(gridIndex / 2) % 6]
    }
}

struct AthkarMoreGridPage: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var allEntries: [AthkarEntry] = []
    @FocusState private var fieldFocused: Bool

    /// Page4 reversed — the capture's exact card order.
    private var cards: [AthkarEntry] {
        let all = allEntries.reversed()
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return Array(all) }
        return all.filter { moreNormalize($0.Title ?? "").contains(moreNormalize(needle)) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                searchPill
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                cardGrid
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if allEntries.isEmpty {
                allEntries = AthkarStore.loadCategories().first { $0.id == "Page4" }?.entries ?? []
            }
            if ProcessInfo.processInfo.environment["DIKHR_MORE_SEARCH"] != nil {
                fieldFocused = true
            }
        }
    }

    // MARK: chrome (title centered, round back chevron top-right)

    private var topBar: some View {
        ZStack {
            Text(settings.t("المزيد", "More"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 18)
        }
        .padding(.top, 34)
        .padding(.bottom, 8)
    }

    // MARK: plain filter pill (مثل صفحة البحث، بدون الذكاء الاصطناعي)

    private var searchPill: some View {
        HStack(spacing: 10) {
            // RTL: the magnifier leads at the right end (like the capture).
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            TextField(settings.t("ابحث ...", "Search ..."), text: $query)
                .focused($fieldFocused)
                .submitLabel(.search)
                .font(.system(size: 17))
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: { query = "" }) {
                    ZStack {
                        Circle().fill(Color(white: 0.35))
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(width: 25, height: 25)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 23)
            .fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 23)
                .stroke(Color.white.opacity(0.16))))
    }

    // MARK: two-column tinted card grid

    private var cardGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)],
                      spacing: 16) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { i, entry in
                    NavigationLink {
                        AthkarPageView(category: AthkarCategory(
                            id: "more|\(entry.Title ?? String(i))",
                            title: entry.Title ?? "",
                            entries: [entry]))
                    } label: {
                        MoreGridCard(title: entry.Title ?? "",
                                     tint: MoreCardTint.tint(for: i).color)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
    }
}

/// One large rounded tile: subtle tinted gradient, bold white RTL title.
private struct MoreGridCard: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [tint,
                                              tint.opacity(0.82)],
                                     startPoint: .top, endPoint: .bottom)))
    }
}

// MARK: - Title normalization for the filter (local, mirrors the search
// page's smart matching: diacritics stripped + hamza/ya unified)

private func moreNormalize(_ text: String) -> String {
    text.unicodeScalars.reduce(into: String()) { out, scal in
        let mapped: UnicodeScalar
        switch scal.value {
        case 0x0671, 0x0623, 0x0625, 0x0622, 0x0672, 0x0673: mapped = "ا"
        case 0x0649, 0x0626: mapped = "ي"
        case 0x0624: mapped = "و"
        default: mapped = scal
        }
        let isMark = (0x064B...0x065F).contains(mapped.value)
            || mapped.value == 0x0670
            || (0x06D6...0x06ED).contains(mapped.value)
            || mapped.value == 0x0640
        if !isMark { out.unicodeScalars.append(mapped) }
    }
}
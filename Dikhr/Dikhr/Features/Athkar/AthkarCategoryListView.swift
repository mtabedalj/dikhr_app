import SwiftUI

/// English titles for the AthkarStore category ids (AthkarStore.categoryTitles
/// stays Arabic; the Data store is not touched by the language switch).
private let athkarCategoryEnglishTitles: [String: String] = [
    "Page1": "Morning Athkar",
    "Page2": "Evening Athkar",
    "Page3": "Sleep Athkar",
    "Page31": "Waking-Up Athkar",
    "Page4": "Authentic Supplications",
    "Page5": "Post-Prayer Athkar",
    "Page6": "Miscellaneous Supplications",
    "Page7": "Supplications from the Quran",
    "Page8": "Prophetic Supplications",
    "AkherAyateen": "Closing Verses",
    "RoqiaQuran": "Ruqyah from the Quran",
    "RoqiaSuna": "Ruqyah of the Sunnah",
    "Tasbee7": "Tasbih",
]

extension AthkarCategory {
    /// Title resolved per Arabic/English mode.
    func localizedTitle(_ lang: SettingsStore.Language) -> String {
        lang == .arabic ? title : (athkarCategoryEnglishTitles[id] ?? title)
    }
}

struct AthkarCategoryListView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var categories: [AthkarCategory] = []
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List(categories) { category in
                NavigationLink(value: category) {
                    HStack(spacing: 12) {
                        Image(systemName: athkarSymbol(category.id))
                            .font(.title3)
                            .foregroundStyle(.accent)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.accent.opacity(0.12)))
                        Text(category.localizedTitle(settings.lang))
                            .font(.title3)
                        Spacer()
                        Text("\(category.entries.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(settings.t("أذكار", "Athkar"))
            .navigationDestination(for: AthkarCategory.self) { category in
                AthkarPageView(category: category)
            }
            .navigationDestination(for: String.self) { key in
                if key == "allahNames" { AllahNamesView() }
                if key == "myAthkar" { MyAthkarView() }
                if key == "khatmah" { KhatmahView() }
            }
            .onAppear {
                if categories.isEmpty { categories = AthkarStore.loadCategories() }
                if let push = ProcessInfo.processInfo.environment["DIKHR_PUSH"] {
                    switch push {
                    case "allahNames": path.append("allahNames")
                    default:
                        if let target = categories.first(where: { $0.id == push }) {
                            path.append(target)
                        }
                    }
                }
                if ProcessInfo.processInfo.environment["DIKHR_LISTEN"] != nil,
                   let target = categories.first(where: { $0.id == "Page1" }) {
                    path.append(target)
                }
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 8) {
                    NavigationLink(value: "khatmah") {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(.accent)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(.accent.opacity(0.12)))
                            Text(settings.t("ورد الختمة", "Khatmah Portion"))
                                .font(.title3)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: "myAthkar") {
                        HStack(spacing: 12) {
                            Image(systemName: "text.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.accent)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(.accent.opacity(0.12)))
                            Text(settings.t("أذكاري", "My Athkar"))
                                .font(.title3)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: "allahNames") {
                        HStack(spacing: 12) {
                            Image(systemName: "star.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.accent)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(.accent.opacity(0.12)))
                            Text(settings.t("أسماء الله الحسنى", "Names of Allah"))
                                .font(.title3)
                            Spacer()
                            Text("\(AthkarStore.loadNinetyNineNames().count)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
        }
    }

    private func athkarSymbol(_ id: String) -> String {
        switch id {
        case "Page1": return "sun.max.fill"
        case "Page2": return "moon.fill"
        case "Page3": return "bed.double.fill"
        case "Page31": return "alarm.fill"
        case "Page5": return "hands.sparkles.fill"
        case "RoqiaQuran", "RoqiaSuna": return "cross.case.fill"
        case "Tasbee7": return "circle.grid.3x3.fill"
        case "Page7": return "book.closed.fill"
        case "AkherAyateen": return "text.book.closed.fill"
        default: return "book.fill"
        }
    }
}

struct AthkarPageView: View {
    let category: AthkarCategory
    @EnvironmentObject private var settings: SettingsStore
    @State private var counted: [Int: Int] = [:]
    @State private var listening = false

    private func countDhikr() {
        StreaksStore.addAthkar(1)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(Array(category.entries.enumerated()), id: \.offset) { index, entry in
                        AthkarCard(entry: entry, timesCounted: counted[index] ?? 0,
                                   isFavorite: settings.favorites.contains(favoriteID(category, entry)),
                                   onIncrement: {
                                       counted[index, default: 0] += 1
                                       countDhikr()
                                   },
                                   onFavorite: { toggleFavorite(category, entry) },
                                   onPlay: { listening = true })
                            .id(index)
                    }
                }
                .padding()
            }
            .navigationTitle(category.localizedTitle(settings.lang))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $listening) {
                AthkarListeningView(category: category)
            }
            .onAppear {
                if ProcessInfo.processInfo.environment["DIKHTML_LISTEN"] != nil ||
                   ProcessInfo.processInfo.environment["DIKHR_LISTEN"] != nil {
                    listening = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AthkarListeningView(category: category)
                    } label: {
                        Image(systemName: "headphones")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Text(settings.t("التكرار: \(counted.values.reduce(0, +))",
                                        "Repeats: \(counted.values.reduce(0, +))"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(action: {
                            let next = (counted.keys.max() ?? -1) + 1
                            if next < category.entries.count {
                                withAnimation { proxy.scrollTo(next, anchor: .center) }
                            }
                        }, label: {
                            Image(systemName: "arrow.down.circle")
                        })
                    }
                }
            }
        }
    }

    private func favoriteID(_ category: AthkarCategory, _ entry: AthkarEntry) -> String {
        let fallback = String(AthkarStore.stripHTML(entry.Athkar ?? "").prefix(24))
        return "\(category.id)|\(entry.Title ?? fallback)"
    }

    private func toggleFavorite(_ category: AthkarCategory, _ entry: AthkarEntry) {
        let id = favoriteID(category, entry)
        if settings.favorites.contains(id) {
            settings.favorites.remove(id)
        } else {
            settings.favorites.insert(id)
        }
    }
}

struct AthkarCard: View {
    @EnvironmentObject private var settings: SettingsStore
    let entry: AthkarEntry
    let timesCounted: Int
    let isFavorite: Bool
    let onIncrement: () -> Void
    let onFavorite: () -> Void
    var onPlay: (() -> Void)? = nil

    private var requiredCount: Int { max(1, entry.Count ?? 1) }
    private var segments: [AthkarTextRenderer.Segment] { AthkarTextRenderer.segments(entry.Athkar ?? "") }
    private var done: Bool { timesCounted >= requiredCount }

    private var buttonLabel: String {
        if done { return settings.t("تم", "Done") }
        if timesCounted == 0 {
            return requiredCount > 1
                ? settings.t("تكرار \(requiredCount)", "Repeat \(requiredCount)")
                : settings.t("عدِّد", "Count")
        }
        return "\(timesCounted)/\(requiredCount)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.Title ?? "")
                    .font(.headline)
                    .foregroundStyle(.accent)
                Spacer()
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(segments) { segment in
                    Text(segment.text)
                        .font(AthkarTextRenderer.font(segment.style))
                        .foregroundStyle(AthkarTextRenderer.foregroundColor(segment.style))
                        .lineSpacing(AthkarTextRenderer.lineSpacing(segment.style))
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(segment.style == .attribution ? .center : .leading)
                }
            }

            HStack {
                if let onPlay, entry.Audio.map({ !$0.isEmpty }) == true {
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.accent)
                    }
                    .buttonStyle(.borderless)
                }
                if requiredCount > 1 {
                    Text(settings.t("تكرار: \(requiredCount)", "Repeat: \(requiredCount)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onIncrement) {
                    Label(buttonLabel,
                          systemImage: done ? "checkmark.circle.fill" : "hand.tap")
                        .font(.callout.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(done ? .green : .accent)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
        .opacity(done ? 0.75 : 1)
    }
}
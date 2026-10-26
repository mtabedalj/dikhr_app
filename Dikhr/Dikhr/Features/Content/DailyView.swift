import SwiftUI

/// A daily-rotated supplication article (أدعية اليوم), baked from the
/// original Content.plist → "Daily" key (32 {title, body} items).
struct DailyArticle: Codable, Identifiable {
    let title: String
    let body: String
    var id: String { title }
}

enum DailyStore {
    static var articles: [DailyArticle] {
        guard let url = Bundle.main.url(forResource: "daily", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [DailyArticle]].self, from: data),
              let items = raw["articles"]
        else { return [] }
        return items
    }

    /// The article of the day: plain day-of-year rotation, matching the
    /// original's daily rotation semantics.
    static func article(for date: Date = Date()) -> DailyArticle? {
        let items = articles
        guard !items.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return items[(day - 1) % items.count]
    }
}

struct DailyView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var articles: [DailyArticle] = []
    @State private var article: DailyArticle?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let a = article {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(settings.t("أدعية اليوم", "Daily Supplications"))
                            .font(.caption.bold())
                            .foregroundStyle(.accent)
                        Text(a.title)
                            .font(.title2.bold())
                        Divider()
                        Text(a.body.isEmpty ? settings.t("لا يوجد نص", "No text") : a.body)
                            .font(.athkarBody)
                            .lineSpacing(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
                    .environment(\.layoutDirection, .rightToLeft)
                }
                NavigationLink {
                    DailyListView(articles: articles)
                } label: {
                    Label(settings.t("عرض الكل", "View All"), systemImage: "list.bullet")
                        .font(.headline)
                        .foregroundStyle(.accent)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.t("أدعية اليوم", "Daily Supplications"))
        .onAppear {
            if articles.isEmpty {
                articles = DailyStore.articles
                article = DailyStore.article()
            }
        }
    }
}

/// All 32 daily supplication articles in one list.
struct DailyListView: View {
    @EnvironmentObject private var settings: SettingsStore
    let articles: [DailyArticle]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(Array(articles.enumerated()), id: \.offset) { _, a in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(a.title)
                            .font(.title3.bold())
                            .foregroundStyle(.accent)
                        if !a.body.isEmpty {
                            Text(a.body)
                                .font(.athkarBody)
                                .lineSpacing(8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground)))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.t("عرض الكل", "View All"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
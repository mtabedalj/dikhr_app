import SwiftUI

struct NewsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var store = NewsStore.shared

    private var isEnglish: Bool { settings.lang == .english }

    private func title(_ item: NewsItem) -> String {
        isEnglish ? (item.titleEN ?? item.title) : item.title
    }

    private func body(_ item: NewsItem) -> String {
        let primary = isEnglish ? (item.bodyEN ?? item.body) : item.body
        return primary.replacingOccurrences(of: "\n", with: " ")
    }

    var body: some View {
        Group {
            if store.items.isEmpty {
                emptyState
            } else {
                feed
            }
        }
        .navigationTitle(settings.t("الأخبار", "News"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var feed: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(store.items) { item in
                    newsCard(item)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "newspaper")
                .font(.system(size: 52))
                .foregroundStyle(ContentPalette.teal.opacity(0.55))
            Text(settings.t("لا أخبار حاليًا", "No news right now"))
                .font(.system(size: 26, weight: .semibold, design: .serif))
            Text(settings.t("سيتم عرض آخر الأخبار والتحديثات هنا عند توفرها",
                            "The latest news and updates will appear here when available"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func newsCard(_ item: NewsItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title(item))
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(ContentPalette.teal)
            if !item.date.isEmpty {
                Text(item.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(body(item))
                .font(isEnglish ? .body : .athkarBody)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground)))
    }
}
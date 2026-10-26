import SwiftUI

struct EventEntry: Identifiable, Codable {
    var name: String
    var details: String
    var source: String

    var id: String { name }

    static func loadAll() -> [EventEntry] {
        guard let url = Bundle.main.url(forResource: "events", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([EventEntry].self, from: data)
        else { return [] }
        return entries
    }
}

/// Card list for the islamic_figures content (32 Arabic-only biographies).
struct EventsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var entries: [EventEntry] = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if entries.isEmpty {
                    Text(settings.t("لا يوجد محتوى", "No content"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 48)
                }
                ForEach(entries) { entry in
                    eventCard(entry)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.t("الشخصيات الإسلامية", "Islamic Figures"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if entries.isEmpty { entries = EventEntry.loadAll() }
        }
    }

    private func eventCard(_ entry: EventEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.name)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(ContentPalette.teal)

            Text(entry.details)
                .font(.athkarBody)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            if !entry.source.isEmpty {
                Divider()
                Text(entry.source)
                    .font(.callout.italic())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground)))
    }
}
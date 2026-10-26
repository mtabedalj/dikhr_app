import SwiftUI

struct AllahNamesView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var names: [(name: String, details: String)] = []
    @State private var query = ""

    private var filtered: [(name: String, details: String)] {
        query.isEmpty ? names : names.filter { $0.name.contains(query) || $0.details.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            ForEach(Array(filtered.enumerated()), id: \.offset) { _, entry in
                HStack {
                    Text(entry.name)
                        .font(.system(size: 21, design: .serif))
                    Spacer()
                    Text(entry.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $query, prompt: settings.t("ابحث في الأسماء", "Search the names"))
        .navigationTitle(settings.t("أسماء الله الحسنى", "Names of Allah"))
        .onAppear {
            if names.isEmpty { names = AthkarStore.loadNinetyNineNames() }
        }
    }
}
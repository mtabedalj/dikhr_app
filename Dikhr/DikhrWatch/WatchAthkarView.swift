import SwiftUI

/// Athkar page for the watch. The original watch app receives sections turned
/// on from the iPhone ("استخدم في الساعة") and shows them as plain text only —
/// here the flow is pushed over WatchConnectivity (fallback: app-group cache).
struct WatchAthkarView: View {
    @State private var sections: [AthkarSectionPlain] = DikhrShared.watchAthkarSections

    var body: some View {
        if sections.isEmpty {
            emptyState
        } else {
            navigationList
        }
    }

    private var navigationList: some View {
        NavigationStack {
            List {
                ForEach($sections) { $section in
                NavigationLink {
                    WatchSectionDetailView(section: section)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(section.text.split(separator: "\n").first ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                }
            }
            .navigationTitle("الأذكار")
            .onReceive(NotificationCenter.default.publisher(for: .watchSectionsChanged)) { _ in
                sections = DikhrShared.watchAthkarSections
            }
            .onAppear { sections = DikhrShared.watchAthkarSections }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "applewatch")
                .foregroundStyle(WatchTheme.accent)
            Text("فعّل (استخدم في الساعة) لأي قسم من الأيفون")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

/// Plain-text reader — the original states watch sections render as simple
/// unformatted text only ("سيظهر هذا القسم في تطبيق الساعة كنص فقط").
struct WatchSectionDetailView: View {
    let section: AthkarSectionPlain

    var body: some View {
        ScrollView {
            Text(section.text)
                .font(WatchTheme.athkarText())
                .lineSpacing(6)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .navigationTitle(section.title)
    }
}
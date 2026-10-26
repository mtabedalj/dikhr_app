import SwiftUI

// Shared accent for the Content/ education features (FAQ / Quiz / Events / News).
enum ContentPalette {
    /// Brand teal — interactive accent across Dikhr.
    static let teal = Color(red: 0x01 / 255, green: 0x8F / 255, blue: 0x9E / 255)
}

struct FaqEntry: Identifiable, Codable {
    var question: String
    var questionEN: String
    var answer: String
    var answerEN: String

    var id: String { question }

    static func loadAll() -> [FaqEntry] {
        guard let url = Bundle.main.url(forResource: "faq", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([FaqEntry].self, from: data)
        else { return [] }
        return entries
    }
}

struct FaqView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var expandedID: String?

    private var entries: [FaqEntry] { Self.entriesCache }

    private static let entriesCache: [FaqEntry] = FaqEntry.loadAll()

    private var isEnglish: Bool { settings.lang == .english }

    private func question(_ e: FaqEntry) -> String {
        isEnglish ? (e.questionEN.isEmpty ? e.question : e.questionEN) : e.question
    }

    private func answer(_ e: FaqEntry) -> String {
        let en = isEnglish ? (e.answerEN.isEmpty ? e.answer : e.answerEN) : e.answer
        return en.replacingOccurrences(of: "\n", with: " ")
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if entries.isEmpty {
                    Text(settings.t("لا توجد أسئلة", "No questions"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 48)
                }
                ForEach(entries) { entry in
                    disclosureRow(entry)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.t("الأسئلة الشائعة", "FAQ"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func disclosureRow(_ entry: FaqEntry) -> some View {
        let isExpanded = expandedID == entry.id
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedID = isExpanded ? nil : entry.id
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(ContentPalette.teal)
                        .frame(width: 14)
                    Text(question(entry))
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                Text(answer(entry))
                    .font(isEnglish ? .body : .athkarBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground)))
    }
}
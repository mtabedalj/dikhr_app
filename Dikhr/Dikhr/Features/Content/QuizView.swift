import SwiftUI

struct QuizEntry: Codable {
    var question: String
    var answer: [String]

    static func loadAll() -> [QuizEntry] {
        guard let url = Bundle.main.url(forResource: "quiz", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([QuizEntry].self, from: data)
        else { return [] }
        return entries
    }
}

struct QuizView: View {
    @EnvironmentObject private var settings: SettingsStore

    private struct QuizRound: Identifiable {
        let id = UUID()
        let question: String
        let options: [String]
        let correctIndex: Int
    }

    @State private var round: QuizRound?
    @State private var selected: Int?
    @State private var score = 0
    @State private var asked = 0
    @State private var lastIndex: Int?

    private static let questions = QuizEntry.loadAll()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if round == nil && Self.questions.isEmpty {
                    Text(settings.t("لا توجد أسئلة", "No questions"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 48)
                } else if let round {
                    scoreCard
                    questionCard(round)
                    optionsCard(round)
                    if selected != nil {
                        nextButton
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.t("اختبار", "Quiz"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if round == nil { newQuestion() }
        }
    }

    // MARK: - Pieces

    private var scoreCard: some View {
        HStack(spacing: 16) {
            Label("\(score)", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(ContentPalette.teal)
            Spacer()
            Text(settings.t("عدد الأسئلة: \(asked)", "Questions asked: \(asked)"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground)))
    }

    private func questionCard(_ round: QuizRound) -> some View {
        Text(round.question)
            .font(.system(size: 24, weight: .semibold, design: .serif))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(ContentPalette.teal.opacity(0.10)))
    }

    private func optionsCard(_ round: QuizRound) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(round.options.enumerated()), id: \.offset) { index, option in
                optionButton(index, option, round: round)
            }
        }
    }

    private func optionButton(_ index: Int, _ option: String, round: QuizRound) -> some View {
        let isSelected = selected == index
        let answerLocked = selected != nil
        let isCorrect = index == round.correctIndex
        var background: Color {
            if answerLocked && isCorrect { return Color.green.opacity(0.18) }
            if isSelected && !isCorrect { return Color.red.opacity(0.18) }
            return Color(.secondarySystemGroupedBackground)
        }
        var tint: Color {
            if answerLocked && isCorrect { return .green }
            if isSelected && !isCorrect { return .red }
            return .primary
        }

        return Button {
            guard answerLocked == false else { return }
            withAnimation(.easeOut(duration: 0.18)) { selected = index }
            if isCorrect { score += 1 }
        } label: {
            HStack(spacing: 10) {
                Text(option)
                    .font(.system(size: 19, design: .serif))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.leading)
                Spacer()
                if answerLocked && isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if isSelected && !isCorrect {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(background))
        }
        .buttonStyle(.plain)
        .disabled(answerLocked)
    }

    private var nextButton: some View {
        Button {
            withAnimation { newQuestion() }
        } label: {
            Text(settings.t("سؤال جديد", "Next Question"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(ContentPalette.teal))
        }
    }

    // MARK: - Logic

    private func newQuestion() {
        let questions = Self.questions
        guard !questions.isEmpty else { return }

        var index = Int.random(in: 0..<questions.count)
        if let lastIndex, questions.count > 1 {
            while index == lastIndex { index = Int.random(in: 0..<questions.count) }
        }
        lastIndex = index

        let entry = questions[index]
        // In the source data the first option is always the correct one;
        // shuffle so its position in the displayed list is random.
        let correct = entry.answer[0]
        var options = entry.answer.shuffled()
        let correctIndex = options.firstIndex(of: correct) ?? 0
        selected = nil
        asked += 1
        round = QuizRound(
            question: entry.question,
            options: options,
            correctIndex: correctIndex)
    }
}
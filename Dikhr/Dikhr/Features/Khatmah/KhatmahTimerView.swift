import SwiftUI

/// Today's portion card (the original's KhatmahTimerView): the daily ورد
/// labeled with its day number, starting surah/ayah/page and juz, with a
/// whole-wird completion button and undo.
struct KhatmahTimerView: View {
    @EnvironmentObject private var settings: SettingsStore
    let portion: KhatmahPortion
    var isDone: Bool
    var onToggle: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(settings.t("ورد اليوم", "Today's Portion"))
                    .font(.headline)
                Spacer()
                Text(settings.t("اليوم \(portion.dayNumber)", "Day \(portion.dayNumber)"))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
            }

            // Quranic label: surah · ayah · page · juz
            VStack(spacing: 6) {
                Text("\(portion.firstSurah) · \(settings.t("آية \(portion.firstAyah)", "ayah \(portion.firstAyah)")) · \(settings.t("صفحة \(portion.firstPage)", "page \(portion.firstPage)"))")
                    .font(.quranUthmani)
                    .foregroundStyle(QuranPalette.darkGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(settings.t("الجزء \(portion.firstJuz) · صفحات \(portion.pages.first!)–\(portion.pages.last!)",
                                "Juz \(portion.firstJuz) · pages \(portion.pages.first!)–\(portion.pages.last!)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(QuranPalette.paper.opacity(0.6)))

            // Page chips — tappable rows are the whole wird here.
            FlexiblePageChips(pages: Array(portion.pages.prefix(12)))

            Button {
                onToggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "book")
                    Text(isDone ? settings.t("تم الورد", "Portion Done") : settings.t("إتمام الورد", "Complete Portion"))
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(isDone ? Color.accentColor.opacity(0.18) : Color.accentColor))
                .foregroundStyle(isDone ? Color.accentColor : .white)
            }
            .buttonStyle(.plain)

            if isDone {
                Button {
                    onToggle()
                } label: {
                    Label(settings.t("تراجع (إلغاء إتمام الورد)", "Undo portion completion"), systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
        .animation(.easeInOut(duration: 0.2), value: isDone)
    }
}

/// Small grid of the portion's page numbers.
private struct FlexiblePageChips: View {
    let pages: [Int]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(pages, id: \.self) { page in
                Text("\(page)")
                    .font(.caption2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(QuranPalette.paper))
                    .foregroundStyle(QuranPalette.darkGreen)
            }
        }
    }
}
import SwiftUI

// MARK: - Friday page / card
//
// Original ground truth (fridayPage.nib scene + Localizable.strings):
//   - "الجمعة" (Friday) — title.
//   - "سنن الجمعة" (en: Friday practices) — the card/page subtitle.
//   - "فضائل يوم الجمعة" (en: Virtues of Friday) — virtues section.
//   - The long virtues hadith text (Muslim 856 + Abu Dawud 1047) quoted
//     verbatim below from the strings file.
//   - "سورة الكهف (الجمعة)" — "من قرأ سورة الكهف في يوم الجمعة أضاء له من
//     النور ما بين الجمعتين".
//   - "ساعة الإجابة يوم الجمعة" — "أكثر من الدعاء حتى أذان المغرب، فآخر ساعة
//     من يوم الجمعة أرجى ساعات إجابة الدعاء."
//   - "يوم الجمعة" / "الإقامة بعد خطبة الجمعة".
// The card is shown only on Friday (local time), matching the original's
// TimeMoments rule "friday" (group "weekly", days [5]).

struct FridayCard: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// True on Friday local time (the original's TimeMoments rule "friday"
    /// is group "weekly", days [5], sunrise → dhuhr).
    private var isFriday: Bool {
        Calendar.current.component(.weekday, from: now) == 6
    }

    private var body_: some View {
        NavigationLink {
            FridayPageView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(.accent)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.t("الجمعة", "Friday"))
                        .font(.headline)
                    Text(settings.t("سنن الجمعة", "Friday Practices"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        Group {
            if isFriday {
                body_
            } else {
                EmptyView()
            }
        }
        .onReceive(timer) { now = $0 }
        .dikhrRefresh(now: $now)
    }
}

struct FridayPageView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle(settings.t("فضائل يوم الجمعة", "Virtues of Friday"))
                paragraph("""
                يوم الجمعة ميزات وفضائل كثيرة ، فَضَّلَ الله بها هذا اليوم على ما سواه من الأيام

                عن أبي هريرة وحذيفة رضي الله عنهما قالا : قال رسول الله صلى الله عليه وسلم : ( أَضَلَّ اللَّهُ عَنْ الْجُمُعَةِ مَنْ كَانَ قَبْلَنَا ، فَكَانَ لِلْيَهُودِ يَوْمُ السَّبْتِ ، وَكَانَ لِلنَّصَارَى يَوْمُ الأَحَدِ ، فَجَاءَ اللَّهُ بِنَا فَهَدَانَا اللَّهُ لِيَوْمِ الْجُمُعَةِ ، فَجَعَلَ الْجُمُعَةَ وَالسَّبْتَ وَالأَحَدَ ، وَكَذَلِكَ هُمْ تَبَعٌ لَنَا يَوْمَ الْقِيَامَةِ ، نَحْنُ الآخِرُونَ مِنْ أَهْلِ الدُّنْيَا ، وَالأَوَّلُونَ يَوْمَ الْقِيَامَةِ ، الْمَقْضِيُّ لَهُمْ قَبْلَ الْخَلائِقِ ) . رواه مسلم (856) .

                وعن أوس بن أبي أوس : عن النبي صلى الله عليه وسلم قال : ( إِنَّ مِنْ أَفْضَلِ أَيَّامِكُمْ يَوْمَ الْجُمُعَةِ ، فِيهِ خُلِقَ آدَمُ عَلَيْهِ السَّلَام ، وَفِيهِ قُبِضَ ، وَفِيهِ النَّفْخَةُ ، وَفِيهِ الصَّعْقَةُ ، فَأَكْثِرُوا عَلَيَّ مِنْ الصَّلَاةِ فَإِنَّ صَلَاتَكُمْ مَعْرُوضَةٌ عَلَيَّ ، قَالُوا : يَا رَسُولَ اللَّهِ ، وَكَيْفَ تُعْرَضُ صَلاتُنَا عَلَيْكَ وَقَدْ أَرَمْتَ -أَيْ يَقُولُونَ قَدْ بَلِيتَ- قَالَ : إِنَّ اللَّهَ عَزَّ وَجَلَّ قَدْ حَرَّمَ عَلَى الأَرْضِ أَنْ تَأْكُلَ أَجْسَادَ الأَنْبِيَاءِ عَلَيْهِمْ السَّلام ) . رواه أبو داود (1047) وصححه ابن القيم في تعليقه على سنن أبي داود (4/273) . وصححه الألباني في صحيح أبي داود (925) .
                """)

                sectionTitle(settings.t("سنن الجمعة", "Friday Practices"))
                paragraph("""
                من اغتسل يوم الجمعة واستنّ ومسّ من طيب إن كان عنده، ولبس من أحسن ثيابه، ثم خرج حتى يأتي المسجد فلم يتخطَّ رقاب الناس، ثم صلّى ما كتب الله له، ثم أنصت إذا خرج إمامه حتى يفرغ من صلاته؛ كانت كفارة لما بينها وبين الجمعة التي قبلها
                """)
                row(settings.t("الإقامة بعد خطبة الجمعة", "Iqama after the Friday sermon"))

                sectionTitle(settings.t("سورة الكهف (الجمعة)", "Surah Al-Kahf (Friday)"))
                paragraph("من قرأ سورة الكهف في يوم الجمعة أضاء له من النور ما بين الجمعتين")
                row(settings.t("سنة قراءتها يوم الجمعة", "Recommended to read it on Friday"))

                sectionTitle(settings.t("ساعة الإجابة يوم الجمعة", "Hour of Answered Prayer on Friday"))
                paragraph("أكثر من الدعاء حتى أذان المغرب، فآخر ساعة من يوم الجمعة أرجى ساعات إجابة الدعاء.")
                paragraph("وقتها من غروب شمس الخميس إلى غروب شمس الجمعة", size: .caption, secondary: true)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.t("الجمعة", "Friday"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.headline)
            .foregroundStyle(.accent)
    }

    private func paragraph(_ text: String,
                           size: Font = .athkarBody,
                           secondary: Bool = false) -> some View {
        Text(verbatim: text)
            .font(size)
            .foregroundStyle(secondary ? Color.secondary : Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }

    private func row(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.accent)
            Text(verbatim: text)
                .font(.callout)
        }
    }
}
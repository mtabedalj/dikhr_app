import SwiftUI

// MARK: - Duha prayer card
//
// Original ground truth (Localizable.strings + TimeMoments.json):
//   - "صلاة الضحى" (en string: "Duha prayer") — label.
//   - "يظهر وقت بداية الضحى في ودجت الوقت." — the original exposes the Duha
//     START time (bداية الضحى) next to the prayer times.
//   - Start options in the original settings: "ربع ساعة بعد الشروق" (15 min
//     after sunrise) and "نصف ساعة بعد الشروق" (30 min after sunrise).
//   - TimeMoments.json rule "duha" (priority 60, group "daily") anchors the
//     Duha moment at sunrise + 20 min, ending dhuhr − 10 min.
// The card therefore shows Duha start = sunrise + 20 min (ground-truth anchor;
// adjust the constant if you wire a settings option for 15/30 min).

struct DuhaCard: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    /// Minutes after sunrise the Duha window opens — ground truth from the
    /// TimeMoments.json rule "duha"; the original settings offer 15 ("ربع ساعة
    /// بعد الشروق") or 30 ("نصف ساعة بعد الشروق").
    static let minutesAfterSunrise = 20

    private var times: PrayerTimes? { HomeCards.resolveTimes(settings: settings, now: now) }

    private var caption: String {
        switch Self.minutesAfterSunrise {
        case 15: return settings.t("ربع ساعة بعد الشروق", "15 minutes after sunrise")
        case 30: return settings.t("نصف ساعة بعد الشروق", "30 minutes after sunrise")
        case let n:
            return settings.t("\(HomeCards.arabicDigits(n)) دقيقة بعد الشروق", "\(n) minutes after sunrise")
        }
    }

    var body: some View {
        NavigationLink {
            DuhaJourneyView()
        } label: {
            Group {
            if let t = times {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.and.horizon")
                            .foregroundStyle(.accent)
                            .frame(width: 30)
                        Text(settings.t("صلاة الضحى", "Duha Prayer"))
                            .font(.headline)
                        Spacer()
                        Text(t.sunrise.addingTimeInterval(
                            TimeInterval(Self.minutesAfterSunrise * 60)),
                            format: .dateTime.hour().minute())
                            .font(.title3)
                            .monospacedDigit()
                            .bold()
                    }
                    Text(verbatim: caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemGroupedBackground)))
            } else {
                EmptyView()
            }
        }
        .onReceive(timer) { now = $0 }
        .dikhrRefresh(now: $now)
        }
        .buttonStyle(.plain)
    }
}
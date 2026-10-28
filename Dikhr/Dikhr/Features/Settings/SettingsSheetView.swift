import SwiftUI
import UserNotifications

// MARK: - Settings bottom sheet (matches the original's settings sheet)
//
// Live capture ground truth (/tmp/athkar_settings.png, original Settings sheet
// opened from the gear button on the athkar home):
//   dimmed background, near-black rounded sheet with a grabber;
//   top row: dark circular MOON button (toggles interface appearance),
//   centered bold white "الإعدادات", X close button;
//   section "التطبيق": card with app-features row (blue thumbnail +
//   "مزايا التطبيق" + right-corner version "v10.0.0"), gold update row,
//   "🔔 تفعيل الإشعارات" + gray explanation + gold pill "فتح إعدادات الإشعارات";
//   card "ويدجت على ذوقك" + "صمم الويدجت المناسب لك" + widget collage +
//   gold "+ ابدأ التصميم" with an RTL back-arrow at its left end;
//   section "النسخة الحصرية": teal gradient card row → paywall ;
//   below the fold the rest of Dikhr's settings sections continue.
//
// Strings are verbatim from the original binary (athkar binary + ar/en
// Localizable.strings):
//   "مزايا التطبيق", "توجد نسخة جديدة، اضغط هنا للتحديث",
//   "تفعيل الإشعارات", "إشعارات أذكار متوقفة على هذا الجهاز. يمكنك تفعيلها من إعدادات النظام.",
//   "فتح إعدادات الإشعارات", "ويدجت على ذوقك" / "Make it your widget",
//   "صمم الويدجت المناسب لك" / "Design the widget that suits you",
//   "ابدأ التصميم", "شكرًا لمساهمتك واشتراكك في التطبيق".
//
// Honest mappings: widget-design card → ThemeSettingsView (Dikhr's widget/theme
// studio); update row → NewsView; gold notification button →
// UIApplication.openSettingsURLString (like the original).

struct SettingsSheetView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    /// The moon button toggles the sheet's interface appearance
    /// (dark like the capture by default, light on moon tap).
    @State private var lightAppearance = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerRow
                SettingsSectionsView(sheetTopCards: true)
            }
        }
        .preferredColorScheme(lightAppearance ? .light : .dark)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationDetents([.large])
    }

    // MARK: header (moon / title / X)

    private var headerRow: some View {
        HStack(spacing: 12) {
            // Moon: toggles sheet appearance (original switches interface style).
            Button {
                lightAppearance.toggle()
            } label: {
                Image(systemName: lightAppearance ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(.tertiarySystemFill)))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(settings.t("الإعدادات", "Settings"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

// MARK: - Special top cards (new version / notifications / widget / Pro)

/// Rendered as one row inside the sheet Form; internal dividers split the
/// "التطبيق" card rows. Cards use `.listRowInsets(.init())` +
/// `.listRowBackground(.clear)`, so each draws its own rounded card.
struct DikhrSettingsTopCards: View {
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var news = NewsStore.shared
    /// True until the device's notification authorization is confirmed —
    /// the original shows this notice while notifications are stopped.
    @State private var notificationsStopped = true

    /// Gold color shared with the athkar home (athkarHomeGold).
    private var gold: Color { Color(red: 0.79, green: 0.65, blue: 0.35) }

    var body: some View {
        VStack(spacing: 14) {
            sectionTitle(settings.t("التطبيق", "App"))
            appCard
            widgetCard
            sectionTitle(settings.t("النسخة الحصرية", "Exclusive Version"))
            proCard
        }
        .padding(.horizontal, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .onAppear {
            UNUserNotificationCenter.current().getNotificationSettings { s in
                Task { @MainActor in
                    notificationsStopped = s.authorizationStatus != .authorized
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: التطبيق card

    private var appCard: some View {
        VStack(spacing: 0) {
            // Row 1: app thumbnail + "مزايا التطبيق" + right-corner version.
            HStack(spacing: 10) {
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text(settings.t("مزايا التطبيق", "App Features"))
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.primary)
                thumbnailSquare
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            Divider().opacity(0.25)
            // Row 2: gold update row (only when a RemoteConfig news version is known).
            if !news.remoteVersion.isEmpty {
                NavigationLink {
                    NewsView()
                } label: {
                    Text(settings.t("توجد نسخة جديدة، اضغط هنا للتحديث",
                                    "A new version is available, tap here to update"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(gold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                Divider().opacity(0.25)
            }
            // Row 3: notifications notice + gold settings button (shown while
            // notifications are stopped on the device, like the original).
            if notificationsStopped {
                notificationsBlock
            }
        }
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemGroupedBackground)))
        .padding(.horizontal, 8)
    }

    /// Blue square app-feature thumbnail (capture: blue tile, left in RTL).
    private var thumbnailSquare: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [Color(red: 0.30, green: 0.55, blue: 0.95),
                                              Color(red: 0.15, green: 0.42, blue: 0.85)],
                                     startPoint: .top, endPoint: .bottom))
            Text("أ")
                .font(.custom("KFGQPCHAFSUthmanicScript-Bold", size: 22))
                .foregroundStyle(.white)
        }
        .frame(width: 42, height: 42)
    }

    private var notificationsBlock: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(spacing: 8) {
                Spacer()
                Text(settings.t("تفعيل الإشعارات", "Enable Notifications"))
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.primary)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Text(settings.t("إشعارات أذكار متوقفة على هذا الجهاز. يمكنك تفعيلها من إعدادات النظام.",
                            "Athkar notifications are stopped on this device. You can enable them in system settings."))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                // Original: UIApplication.openSettingsURLString.
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(settings.t("فتح إعدادات الإشعارات", "Open Notification Settings"))
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(gold.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
    }

    // MARK: ويدجت على ذوقك card

    private var widgetCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                widgetCollage
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(settings.t("ويدجت على ذوقك", "Make it your widget"))
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(settings.t("صمم الويدجت المناسب لك", "Design the widget that suits you"))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }
            // "+ ابدأ التصميم" with the RTL back-arrow at the left end —
            // pushes Dikhr's widget/theme studio (honest mapping).
            NavigationLink {
                ThemeSettingsView()
            } label: {
                Text(settings.t("+ ابدأ التصميم", "+ Start Designing"))
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(red: 0.13, green: 0.10, blue: 0.03))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(gold))
                    .overlay(alignment: .leading) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 0.13, green: 0.10, blue: 0.03))
                            .padding(.leading, 18)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemGroupedBackground)))
        .padding(.horizontal, 8)
    }

    /// Small collage of sample-widget tiles (capture: two overlapping tiles).
    private var widgetCollage: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 46, height: 60)
                .rotationEffect(.degrees(-7))
                .overlay(
                    VStack(spacing: 3) {
                        Image(systemName: "sun.max.fill").font(.system(size: 11))
                        Text("تسبيح").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(-7))
                )
            VStack(spacing: 3) {
                Image(systemName: "plus.circle.fill").font(.system(size: 11))
                Text("الحمد لله").font(.system(size: 9, weight: .bold))
                Capsule().fill(.clear).frame(height: 2)
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 7)
            .frame(width: 52, height: 52)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
            .rotationEffect(.degrees(6))
            .offset(x: 16)
        }
        .frame(width: 78, height: 72)
    }

    // MARK: النسخة الحصرية card (teal gradient → paywall)

    private var proCard: some View {
        NavigationLink {
            ProPayView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(settings.t("النسخة الحصرية", "Exclusive Version"))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                    Text(settings.t("شكرًا لمساهمتك واشتراكك في التطبيق",
                                    "Thank you for your contribution and subscription to the app"))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Image(systemName: "crown.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [Color(red: 0.02, green: 0.42, blue: 0.45),
                                                  Color(red: 0.01, green: 0.22, blue: 0.26)],
                                         startPoint: .topTrailing, endPoint: .bottomLeading))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}


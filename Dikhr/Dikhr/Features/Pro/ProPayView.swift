import SwiftUI
import StoreKit

/// Payment page (الاشتراك الاحترافي), mirroring the original's PayPage idea:
/// Arabic perks list, price line, subscribe + restore buttons, loading states.
struct ProPayView: View {
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var store = ProStore.shared
    @State private var celebrate = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if store.isPro {
                    activeView
                } else {
                    paywall
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.t("الاشتراك الاحترافي", "Premium Subscription"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !store.isPro {
                await store.loadProduct()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.accent)
                .padding(.top, 8)
            Text(settings.t("اشترك في النسخة الاحترافية", "Subscribe to Premium"))
                .font(.title3.weight(.semibold))
            Text(settings.t("نسخة أنظف وأخف، ودعم مستمر لتطبيق ذكر",
                            "A cleaner, lighter app with ongoing support for Dikhr"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Perks

    private var perks: some View {
        GroupBox {
            VStack(spacing: 14) {
                perk(settings.t("بلا إعلانات", "No ads"), systemImage: "eye.slash")
                perk(settings.t("دعم التطبيق واستمراره", "Support the app's future"), systemImage: "heart")
                perk(settings.t("كل المزايا مفتوحة", "All features unlocked"), systemImage: "checkmark.seal")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func perk(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.accent)
                .frame(width: 28)
            Text(title)
            Spacer()
        }
    }

    // MARK: - Paywall

    @ViewBuilder
    private var paywall: some View {
        perks

        priceLine

        switch store.payState {
        case .loading, .purchasing, .idle:
            VStack(spacing: 12) {
                if case .purchasing = store.payState {
                    Text(settings.t("جارٍ إتمام الشراء…", "Completing purchase…"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        case .unavailable:
            Label(settings.t("الاشتراك غير متاح للمعاينة", "Subscription unavailable in the preview"), systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        case .ready, .purchased:
            EmptyView()
        }

        if let product = store.payState.product {
            Button {
                Task { await store.purchase(product) }
            } label: {
                Text(settings.t("اشترك الآن", "Subscribe Now"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
            .disabled(store.payState.isBusy)
        }

        Button {
            Task { await store.restore() }
        } label: {
            HStack(spacing: 8) {
                if store.payState.isBusy {
                    ProgressView().controlSize(.small)
                }
                Text(settings.t("استعادة المشتريات", "Restore Purchases"))
            }
            .foregroundStyle(.accent)
        }
        .disabled(store.payState.isBusy)

        Text(settings.t("اشتراك سنوي يجدد تلقائيًا، ويمكن إلغاؤه من إعدادات حسابك في App Store.",
                        "Annual subscription that renews automatically; cancel from your App Store account settings."))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var priceLine: some View {
        if let product = store.payState.product {
            Text("\(product.displayPrice) / \(settings.t("سنويًا", "yearly"))")
                .font(.headline)
        } else {
            Text(settings.t("سعر الاشتراك السنوي يظهر عند توفره",
                            "The annual subscription price appears when available"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Active subscription

    private var activeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.accent)
                .scaleEffect(celebrate ? 1.0 : 0.6)
            Text(settings.t("أنت مشترك الآن", "You're Subscribed"))
                .font(.title3.weight(.semibold))
            Text(settings.t("شكرًا لدعمك تطبيق ذكر. كل مزايا النسخة الاحترافية مفعّلة.",
                            "Thank you for supporting Dikhr. All premium features are enabled."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await store.refreshEntitlement() }
            } label: {
                Text(settings.t("تحديث حالة الاشتراك", "Refresh Subscription Status"))
                    .foregroundStyle(.accent)
            }
        }
        .padding(.top, 24)
        .onAppear {
            withAnimation(.spring(response: 0.5)) { celebrate = true }
        }
    }
}
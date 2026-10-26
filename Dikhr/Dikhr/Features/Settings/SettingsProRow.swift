import SwiftUI

struct SettingsProRow: View {
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var pro = ProStore.shared

    var body: some View {
        NavigationLink {
            ProPayView()
        } label: {
            HStack {
                Text(settings.t("الاشتراك الاحترافي", "Premium Subscription"))
                if pro.isPro {
                    Text("Pro")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.accent.opacity(0.18)))
                        .foregroundStyle(.accent)
                }
                Spacer()
            }
        }
    }
}
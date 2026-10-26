import SwiftUI
import FamilyControls

struct PrayerFocusSettingsRow: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var manager = PrayerFocusManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(settings.t("تفعيل عُفص الصلاة", "Enable Prayer Focus"), isOn: $manager.enabled)
                .disabled(!manager.enabled && !manager.authorized && manager.needsAuth)
                .onChange(of: manager.enabled) { _, on in
                    Task {
                        if on {
                            await manager.requestAuthorization()
                            await manager.applySchedule()
                        }
                    }
                }
            if manager.enabled {
                if manager.authorized {
                    Label(settings.t("تُحجب التطبيقات الأخرى أثناء كل صلاة (من ٥ دقائق قبل الأذان إلى ٢٠ دقيقة بعده).", "Other apps are blocked during every prayer (from 5 minutes before the adhan until 20 minutes after)."), systemImage: "checkmark.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Label(settings.t("يلزم منح صلاحية \"وقت العائلة\" من النظام.", "You need to grant \"Screen Time\" permission in system Settings."), systemImage: "exclamationmark.shield")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    Button(settings.t("منح الصلاحية", "Grant Permission")) {
                        Task { await manager.requestAuthorization() }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

extension PrayerFocusManager {
    var needsAuth: Bool { !authorized }
}
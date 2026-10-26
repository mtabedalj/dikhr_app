import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Shown when a shielded app is opened during the prayer-focus window.
class PrayerFocusShieldExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: ManagedSettings.Application) -> ShieldConfiguration {
        makeShield()
    }

    override func configuration(shielding webDomain: ManagedSettings.WebDomain) -> ShieldConfiguration {
        makeShield()
    }

    override func configuration(shielding application: ManagedSettings.Application, in category: ManagedSettings.ActivityCategory) -> ShieldConfiguration {
        makeShield()
    }

    private func makeShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            icon: UIImage(systemName: "moon.stars.fill"),
            title: ShieldConfiguration.Label(text: "وقت الصلاة", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "عُفص الصلاة مُفعّل — أفْضِ إلى الصلاة، وستعود للمتابعة بعد الإقامة بإذن الله.",
                color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "متابعة", color: .white),
            primaryButtonBackgroundColor: .systemTeal
        )
    }
}
import SwiftUI
import UIKit

struct ThemeSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var icons: [(String, UIImage?)] = []

    var body: some View {
        Form {
            Section(settings.t("لون التطبيق", "App Color")) {
                HStack {
                    ForEach(0..<ThemePalette.colors.count, id: \.self) { idx in
                        Button {
                            settings.accentIndex = idx
                        } label: {
                            ZStack {
                                Circle().fill(ThemePalette.colors[idx])
                                    .frame(width: 40, height: 40)
                                if settings.accentIndex == idx {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section(settings.t("الوضع", "Mode")) {
                Picker(settings.t("المظهر", "Appearance"), selection: $settings.appearanceMode) {
                    Text(settings.t("حسب الجهاز", "System")).tag("system")
                    Text(settings.t("فاتح", "Light")).tag("light")
                    Text(settings.t("داكن", "Dark")).tag("dark")
                }
                .pickerStyle(.segmented)
            }
            Section(settings.t("أيقونة التطبيق", "App Icon")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84))], spacing: 12) {
                    defaultIconTile
                    ForEach(icons, id: \.0) { name, image in
                        iconTile(name, image: image)
                    }
                }
            }
        }
        .navigationTitle(settings.t("الثيم", "Theme"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadIcons)
    }

    private var currentIcon: String? { UIApplication.shared.alternateIconName }

    private var defaultIconTile: some View {
        iconTile(nil, image: UIImage(named: "AppIcon"), label: settings.t("افتراضي", "Default"))
    }

    private func iconTile(_ name: String?, image: UIImage?, label: String = "") -> some View {
        Button {
            if name == nil {
                try? UIApplication.shared.setAlternateIconName(nil)
            } else if let name {
                try? UIApplication.shared.setAlternateIconName(name)
            }
        } label: {
            VStack(spacing: 4) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(.accent.opacity(0.15))
                            Image(systemName: "app.fill").foregroundStyle(.accent)
                        }
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(currentIcon == name ? Color.accentColor : .clear, lineWidth: 2.5)
                )
                Text(name == nil ? label : (name?.replacingOccurrences(of: "AppIcon-", with: "") ?? ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func loadIcons() {
        let names = (10...17).map { "AppIcon-\($0)" }
        icons = names.map { ($0, UIImage(named: $0)) }
    }
}
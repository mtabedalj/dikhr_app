import SwiftUI

/// Per-section "استخدم في الساعة" toggles, mirroring the original's
/// "الويدجت وساعة أبل" preferences pane. Changes push immediately to the
/// watch via WatchPhoneBridge. Presented from a Settings row (wiring request).
struct WatchSectionsSettingsView: View {
    @State private var categories: [AthkarCategory] = AthkarStore.loadCategories()
    @State private var enabled: Set<String> = DikhrShared.watchSectionIDs

    var body: some View {
        List {
            if !enabledIDs().isEmpty && !disabledIDs().isEmpty {
                Section("مُفعّل على الساعة") {
                    ForEach(enabledIDs(), id: \.self) { sectionRow($0) }
                }
                Section("غير مُفعّل") {
                    ForEach(disabledIDs(), id: \.self) { sectionRow($0) }
                }
            } else {
                Section {
                    ForEach(categories, id: \.id) { sectionRow($0.id) }
                }
            }
        }
        .navigationTitle("استخدم في الساعة")
        .onAppear {
            categories = AthkarStore.loadCategories()
            enabled = DikhrShared.watchSectionIDs
        }
        .onDisappear {
            WatchPhoneBridge.shared.sectionTogglesChanged()
        }
    }

    @ViewBuilder
    private func sectionRow(_ id: String) -> some View {
        let title = categories.first(where: { $0.id == id })?.title ?? id
        Toggle(title, isOn: Binding(
            get: { enabled.contains(id) },
            set: { on in
                if on { enabled.insert(id) } else { enabled.remove(id) }
                DikhrShared.saveWatchSectionIDs(enabled)
                WatchPhoneBridge.shared.sectionTogglesChanged()
            }
        ))
    }

    private func enabledIDs() -> [String] {
        categories.filter { enabled.contains($0.id) }.map { $0.id }
    }

    private func disabledIDs() -> [String] {
        categories.filter { !enabled.contains($0.id) }.map { $0.id }
    }
}
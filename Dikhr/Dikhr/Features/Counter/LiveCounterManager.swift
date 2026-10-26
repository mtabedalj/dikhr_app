import Foundation
import SwiftUI

// MARK: - Live counter manager (app side)

/// Manages the counter Live Activity (العداد الحيّ) from the app process:
/// start on toggle-on, keep the content state in sync with CounterStore
/// changes, end on toggle-off.
/// Counter changes are observed through the "dikhr-counter-changed"
/// NotificationCenter event posted by CounterView.
@MainActor
final class LiveCounterManager: ObservableObject {
    static let shared = LiveCounterManager()
    static let counterChangedNotification = Notification.Name("dikhr-counter-changed")
    private static let enabledDefaultsKey = "liveCounterEnabled"

    @Published private(set) var isRunning: Bool = DikhrShared.defaults.bool(forKey: LiveCounterManager.enabledDefaultsKey)

    private var observer: NSObjectProtocol?
    /// Returns the counter whose count should be mirrored in the Live Activity
    /// (usually the currently-selected counter in CounterView).
    private var currentProvider: () -> SavedCounter?

    private init(currentProvider: @escaping () -> SavedCounter? = { DikhrShared.loadCounters().first }) {
        self.currentProvider = currentProvider
        registerObserver()
    }

    // MARK: Start / stop

    func start() {
        guard let counter = currentProvider() else { return }
        DikhrLiveActivity.start(count: counter.count, name: counter.name)
        isRunning = true
        DikhrShared.defaults.set(true, forKey: Self.enabledDefaultsKey)
    }

    func stop() {
        DikhrLiveActivity.end()
        isRunning = false
        DikhrShared.defaults.set(false, forKey: Self.enabledDefaultsKey)
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    // MARK: Sync

    /// Mirrors the latest counter value into any running Live Act­ivity.
    func refresh() {
        guard isRunning, let counter = currentProvider() else { return }
        DikhrLiveActivity.update(count: counter.count, name: counter.name)
    }

    private func registerObserver() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: Self.counterChangedNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Toggle view for the counter screen

/// Embed in CounterView (e.g. under the buttons row): shows "بدء النشاط الحيّ"
/// and starts/ends the counter Live Activity like the original's refresh flow.
struct LiveCounterToggle: View {
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var manager = LiveCounterManager.shared
    private let counterProvider: () -> SavedCounter?

    init(counter: @escaping () -> SavedCounter? = { DikhrShared.loadCounters().first }) {
        self.counterProvider = counter
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { manager.isRunning },
            set: { _ in manager.toggle() })) {
            Label(settings.t("بدء النشاط الحي", "Live Activity"), systemImage: "livephoto")
                .font(.subheadline.bold())
        }
        .tint(Color(red: 0.008, green: 0.561, blue: 0.620))
        .padding(.horizontal)
        .onAppear {
            // Keep the manager pointed at the currently-selected counter.
            manager.setCurrentProvider(counterProvider)
            if manager.isRunning { manager.refresh() }
        }
    }
}

extension LiveCounterManager {
    /// Lets Toggle embedders point the mirror at the selected counter.
    func setCurrentProvider(_ provider: @escaping () -> SavedCounter?) {
        currentProvider = provider
    }
}
import SwiftUI

// MARK: - Adaptive root (iPad split layout, original-Athkar style)
//
// Compact (iPhone): renders the caller-provided content (RootTabView's
// `tabViewRoot` TabView) unchanged — zero behavior difference.
//
// Regular (iPad): renders a NavigationSplitView whose sidebar mirrors
// RootTabView's five tabs with the same Arabic labels, SF Symbols and tags
// ("home"/"athkar"/"counter"/"quran"/"settings"), plus a sixth أذكاري row
// (quick-action "myAthkar") that opens MyAthkarView in the detail column.
//
// Router contract (unchanged, all owned by RootTabView):
//  - Deep-link/quick-action tab changes flow through RootTabView's
//    `router.$pendingTab` → its `selection` @State → the `externalSelection`
//    binding passed here, which drives the sidebar selection.
//  - Sidebar taps write back through the same binding, so RootTabView's
//    `AnalyticsService.screen(tab)` keeps firing identically.
//  - The app-level modifiers (tint, preferredColorScheme, layoutDirection —
//    so the Arabic sidebar labels are RTL-native), remain applied by the
//    caller on this container.

// MARK: Destination model

/// Builder enum for the five root destinations — mirrors RootTabView's
/// tabViewRoot exactly (same views, same tags).
enum DikhrDestination: String, CaseIterable, Identifiable, Hashable {
    case home, athkar, counter, quran, settings

    var id: String { rawValue }

    /// Identical to RootTabView's tags and DeepLinkRouter.tabTag values.
    var tag: String { rawValue }

    var title: String {
        switch self {
        case .home: "مواقيت الصلاة"
        case .athkar: "أذكار"
        case .counter: "العداد"
        case .quran: "القرآن"
        case .settings: "الإعدادات"
        }
    }

    var icon: String {
        switch self {
        case .home: "clock"
        case .athkar: "book"
        case .counter: "stopwatch"
        case .quran: "text.book.closed"
        case .settings: "gearshape"
        }
    }

    static func from(tag: String) -> DikhrDestination? {
        DikhrDestination(rawValue: tag)
    }

    /// Each of the five root views already owns its own NavigationStack,
    /// so they are reused as-is (no re-wrapping).
    @MainActor @ViewBuilder var destination: some View {
        switch self {
        case .home: HomeView()
        case .athkar: AthkarCategoryListView()
        case .counter: CounterView()
        case .quran: QuranView()
        case .settings: SettingsView()
        }
    }
}

// MARK: Sidebar

struct DikhrSidebar: View {
    /// Selection held as root tags ("home"/"athkar"/…), so the same strings
    /// flow up to RootTabView and its router consumption.
    @Binding var selection: String
    /// أذكاري (sixth row) is intentionally NOT a router tag: it selects
    /// the athkar destination and sets router.pendingAction = "myAthkar",
    /// matching RootTabView's existing quick-action semantics.
    @Binding var myAthkarActive: Bool

    var body: some View {
        List {
            ForEach(DikhrDestination.allCases) { destination in
                Label(destination.title, systemImage: destination.icon)
                    .tag(destination.tag)
            }
            Button {
                selection = DikhrDestination.athkar.tag
                myAthkarActive = true
                DeepLinkRouter.shared.pendingAction = "myAthkar"
            } label: {
                Label("أذكاري", systemImage: "text.badge.plus")
                    .foregroundStyle(myAthkarActive ? Color.accent : Color.primary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("دِكْر")
    }
}

// MARK: Adaptive container

struct DikhrAdaptiveRoot<CompactContent: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Caller's live selection (RootTabView's @State seedable via
    /// DIKHR_TAB / DIKHTML_TAB env vars and consumed pendingTab).
    /// Pass nil to keep selection fully local (previews, standalone use).
    private let externalSelection: Binding<String>?
    private let compactContent: () -> CompactContent

    @State private var internalSelection = DikhrDestination.home.tag
    @State private var myAthkarActive = false

    init(
        externalSelection: Binding<String>? = nil,
        @ViewBuilder content compactContent: @escaping () -> CompactContent
    ) {
        self.externalSelection = externalSelection
        self.compactContent = compactContent
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                splitRoot
            } else {
                compactContent()
            }
        }
        .onChange(of: externalSelection?.wrappedValue ?? nil) { _, tag in
            if let tag { adoptExternal(tag) }
        }
        .onAppear {
            if let tag = externalSelection?.wrappedValue {
                adoptExternal(tag)
            }
        }
    }

    // MARK: Split layout (iPad)

    private var splitRoot: some View {
        NavigationSplitView {
            DikhrSidebar(selection: selectionBinding, myAthkarActive: $myAthkarActive)
        } detail: {
            splitDetail
        }
    }

    /// Two-way selection: sidebar taps write both the internal state and the
    /// caller's binding (so RootTabView's AnalyticsService.screen and any
    /// consumers keep observing the same tag values).
    private var selectionBinding: Binding<String> {
        Binding(
            get: { internalSelection },
            set: { tag in
                internalSelection = tag
                myAthkarActive = false
                externalSelection?.wrappedValue = tag
            }
        )
    }

    /// Router-driven selection (pendingTab → caller's selection → echo here).
    /// The echo of our own sidebar tap is ignored (same tag already), which is
    /// what keeps the أذكاري detail stable when its external write reflects.
    private func adoptExternal(_ tag: String) {
        let mapped = DikhrDestination.from(tag: tag)?.tag ?? DikhrDestination.home.tag
        guard mapped != internalSelection else { return }
        internalSelection = mapped
        myAthkarActive = false
    }

    @ViewBuilder
    private var splitDetail: some View {
        if myAthkarActive, internalSelection == DikhrDestination.athkar.tag {
            NavigationStack {
                MyAthkarView()
                    .navigationTitle("أذكاري")
            }
        } else {
            (DikhrDestination.from(tag: internalSelection) ?? DikhrDestination.home).destination
        }
    }
}

// MARK: - Previews

private struct DikhrAdaptiveRootPreview: View {
    @State private var selection = "home"

    var body: some View {
        DikhrAdaptiveRoot(externalSelection: $selection) {
            Text("Compact content (TabView) goes here")
        }
    }
}

#Preview("iPad split layout", traits: .fixedLayout(width: 1194, height: 834)) {
    DikhrAdaptiveRootPreview()
        .environment(\.horizontalSizeClass, .regular)
        .environmentObject(SettingsStore.shared)
}
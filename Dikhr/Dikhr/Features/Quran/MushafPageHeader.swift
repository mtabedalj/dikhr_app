import SwiftUI
import WebKit

// MARK: - Mushaf page header (the original's ornate top bar — live capture
// /tmp/athkar_result_jump.png)
//
// The original's mushaf (surah view + printed pages) top bar, from right to
// left: a round back chevron, the ornate hexagon title frame — a bordered
// capsule holding "السور / ٩٧ / جزء ٤" with a small bookmark ribbon — and a
// round "…" button opening the per-page actions menu (share page image /
// mode toggle / jump to page). Shared by QuranPagesView and QuranSurahView's
// mushaf mode. Forces RTL internally so the chevron lands on the far (right)
// edge exactly like the captured chrome.

// MARK: - Weak webview registry (for the takeSnapshot share)

/// Registration of the currently rendered mushaf webviews, keyed by printed
/// page ("page:N") or the surah flow ("surah:N"). Held weakly, so stale webviews
/// released by page flips disappear on their own; the header's share action
/// snapshots the one matching the visible page (WKWebView.takeSnapshot).
@MainActor
final class MushafWebViewRegistry {
    static let shared = MushafWebViewRegistry()

    private struct Entry { weak var webview: WKWebView? }
    private var entries: [String: Entry] = [:]

    func register(_ webview: WKWebView, key: String) {
        entries[key] = Entry(webview: webview)
    }

    func snapshot(key: String) async -> UIImage? {
        guard let webview = entries[key]?.webview else { return nil }
        return await withCheckedContinuation { continuation in
            webview.takeSnapshot(with: nil) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    static func pageKey(_ page: Int) -> String { "page:\(page)" }
    static func surahKey(_ surah: Int) -> String { "surah:\(surah)" }
}

/// The jump-to-page input accepts Western or Arabic-Indic digits (٠–٩).
enum MushafNumberInput {
    static func parse(_ text: String) -> Int? {
        let mapped = text.map { ch -> Character in
            if let scalar = ch.unicodeScalars.first,
               scalar.value >= 0x0660, scalar.value <= 0x0669 {
                return Character(Unicode.Scalar(UInt32(0x30) +
                                                (scalar.value - 0x0660))!)
            }
            return ch
        }
        return Int(String(mapped))
    }
}

/// UIActivityViewController wrapper — the "…" menu's share rows share either
/// the snapshotted mushaf page image or a text fallback in one step
/// (ShareLink needs its item up front; the snapshot arrives async).
struct MushafShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct MushafPageHeader<Trailing: View>: View {
    @EnvironmentObject private var settings: SettingsStore
    /// Right capsule segment (the capture's "السور" — or the surah's name in
    /// the surah flow); the small bookmark ribbon rides beside it.
    let ribbonLabel: String
    /// Center segment: the printed page number (bold, large) in the capture.
    let centerText: String
    /// Left segment: "جزء N".
    let juzText: String
    let onBack: () -> Void
    /// The ribbon segment is tappable where a jump target exists (the pages
    /// view's ribbon opens the surah list); nil leaves it decorative.
    var onRibbon: (() -> Void)? = nil
    @ViewBuilder var actionsMenu: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                headerCircle("chevron.backward")
            }
            .buttonStyle(.plain)
            Spacer()
            titleCapsule
            Spacer()
            Menu { actionsMenu() } label: {
                headerCircle("ellipsis")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(QuranPalette.paper)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var titleCapsule: some View {
        HStack(spacing: 8) {
            ribbonSegment
            hairline
            Text(centerText)
                .font(.system(size: 19, weight: .bold))
            hairline
            Text(juzText)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(QuranPalette.darkGreen)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(QuranPalette.paper))
        .overlay(Capsule().stroke(QuranPalette.darkGreen.opacity(0.55), lineWidth: 1))
    }

    /// "السور" + the small bookmark ribbon icon (tappable where wired).
    private var ribbonSegment: some View {
        Group {
            if let onRibbon {
                Button(action: onRibbon) { segment }
                    .buttonStyle(.plain)
            } else {
                segment
            }
        }
    }

    private var segment: some View {
        HStack(spacing: 5) {
            Text(ribbonLabel)
                .font(.system(size: 14, weight: .semibold))
            Image(systemName: "bookmark.fill")
                .font(.system(size: 10, weight: .semibold))
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(QuranPalette.darkGreen.opacity(0.30))
            .frame(width: 1, height: 18)
    }

    private func headerCircle(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(QuranPalette.darkGreen)
            .frame(width: 40, height: 40)
            .background(Circle().fill(QuranPalette.darkGreen.opacity(0.10)))
            .contentShape(Circle())
    }
}
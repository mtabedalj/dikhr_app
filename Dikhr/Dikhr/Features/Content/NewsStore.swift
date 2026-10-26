import Foundation
import Combine

/// One news entry. Arabic-first copy, same shape a future RemoteConfig feed
/// (the original's `athkarNews`/`athkarNewsVersion`) can decode directly.
struct NewsItem: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var body: String
    /// ISO-8601 or display-ready string; kept as String so feeds stay simple.
    var date: String
    var titleEN: String?
    var bodyEN: String?
}

/// Local, persisted news feed.
///
/// Dikhr has no backend yet, so the feed starts empty; the original app filled
/// this from Firebase RemoteConfig (`athkarNewsVersion`). When a backend is
/// wired, call `applyRemoteVersion(_:items:)` — the store deduplicates by
/// version key and persists only what changed, so nothing else moves.
final class NewsStore: ObservableObject {
    static let shared = NewsStore()

    private static let itemsKey = "newsItems"
    private static let versionKey = "newsVersion"

    @Published private(set) var items: [NewsItem] = [] {
        didSet {
            if items != oldValue {
                persist()
            }
        }
    }
    @Published private(set) var remoteVersion: String

    private init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: Self.itemsKey),
           let saved = try? JSONDecoder().decode([NewsItem].self, from: data) {
            items = saved
        }
        remoteVersion = d.string(forKey: Self.versionKey) ?? ""
    }

    /// Replace the feed wholesale (e.g. a future RemoteConfig JSON array).
    /// Version is tracked so unchanged fetches can be skipped by the caller.
    func applyRemoteVersion(_ version: String, items newItems: [NewsItem]) {
        remoteVersion = version
        UserDefaults.standard.set(remoteVersion, forKey: Self.versionKey)
        items = newItems.sorted { $0.date > $1.date }
    }

    /// Append a single locally-broadcast item (marketing, Ramadan announcement…).
    func add(_ item: NewsItem) {
        guard !items.contains(item) else { return }
        items.insert(item, at: 0)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.itemsKey)
        }
    }
}
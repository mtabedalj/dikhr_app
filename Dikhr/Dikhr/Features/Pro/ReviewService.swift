import Foundation
import StoreKit
import SwiftUI

/// In-app review prompt on milestones, like the original's Reviews.json flow:
/// counts app openings and requests a review every 7th opening.
enum ReviewService {
    static let openingsKey = "reviewOpenings"
    static let interval = 7

    /// Call once per app launch (e.g. from the root tab's onAppear with the
    /// SwiftUI `requestReview` environment action).
    ///
    /// - Parameter viewContext: the environment's `\.requestReview` action;
    ///   when nil falls back to SKStoreReviewController.
    @MainActor
    private static let lastPromptKey = "reviewLastPromptDate"

    @MainActor
    static func maybePrompt(viewContext: RequestReviewAction? = nil) {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: openingsKey) + 1
        defaults.set(count, forKey: openingsKey)
        // Cooldown: at most one prompt attempt per 7 days, however often the
        // app opens (Apple enforces system-side caps on devices).
        if let last = defaults.object(forKey: lastPromptKey) as? Date,
           Date().timeIntervalSince(last) < 7 * 86_400 {
            return
        }
        guard count % interval == 0 else { return }
        UserDefaults.standard.set(Date(), forKey: lastPromptKey)
        requestReview(viewContext: viewContext)
    }

    /// Forces a review request regardless of the opening counter (test hook).
    @MainActor
    static func requestReview(viewContext: RequestReviewAction? = nil) {
        if let viewContext {
            viewContext()
        } else {
            UIApplication.shared.open(URL(string: "itms-apps://itunes.apple.com/app") ?? URL(fileURLWithPath: "/"))
        }
    }
}
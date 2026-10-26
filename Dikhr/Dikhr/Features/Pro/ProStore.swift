import Foundation
import StoreKit

/// StoreKit 2 wrapper for the Pro subscription (الاشتراك الاحترافي), mirroring
/// the original's Jar99 paywall without any storekit config dependency: on a
/// simulator product fetch fails or returns nothing and the UI degrades to a
/// fallback message.
@MainActor
final class ProStore: ObservableObject {
    static let productID = "DikhrPro"
    static let shared = ProStore()

    private static let isProKey = "isPro"

    @Published var isPro: Bool {
        didSet { UserDefaults.standard.set(isPro, forKey: Self.isProKey) }
    }

    enum PayState {
        case idle
        case loading
        case ready(Product)
        case unavailable
        case purchasing
        case purchased
        case failed(String)

        var product: Product? {
            if case .ready(let product) = self { return product }
            return nil
        }

        var isBusy: Bool {
            switch self {
            case .loading, .purchasing: return true
            default: return false
            }
        }
    }

    @Published var payState: PayState = .idle

    private var updatesTask: Task<Void, Never>?

    private init() {
        if ProcessInfo.processInfo.environment["DIKHR_PRO"] == "1" {
            isPro = true
        } else {
            isPro = UserDefaults.standard.bool(forKey: Self.isProKey)
        }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await self.finish(transaction)
                }
            }
        }
        Task { await refreshEntitlement() }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Fetches the annual product. On failure or an empty response (typical on
    /// the simulator) the state degrades to `.unavailable` for fallback UI.
    func loadProduct() async {
        guard !isPro else { return }
        payState = .loading
        do {
            let products = try await Product.products(for: [Self.productID])
            if let product = products.first {
                payState = .ready(product)
            } else {
                payState = .unavailable
            }
        } catch {
            payState = .unavailable
        }
    }

    func purchase(_ product: Product) async {
        payState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await finish(transaction)
                    payState = .purchased
                } else {
                    payState = .failed(DikhrStrings.tr("تعذر التحقق من صحة الشراء", "Could not verify the purchase"))
                }
            case .userCancelled:
                payState = .ready(product)
            case .pending:
                payState = .ready(product)
            @unknown default:
                payState = .ready(product)
            }
        } catch {
            payState = .failed(DikhrStrings.tr("فشل الشراء، حاول مرة أخرى", "Purchase failed, please try again"))
        }
    }

    func restore() async {
        payState = .loading
        do {
            try await AppStore.sync()
        } catch {
            // Keep going: current entitlements may still contain the purchase.
        }
        await refreshEntitlement()
        if isPro {
            payState = .purchased
        } else {
            payState = .failed(DikhrStrings.tr("لم يتم العثور على اشتراك سابق", "No previous subscription found"))
        }
    }

    /// Re-checks active entitlements and updates isPro accordingly.
    func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                isPro = true
                return
            }
        }
        if ProcessInfo.processInfo.environment["DIKHR_PRO"] != "1" {
            isPro = false
        }
    }

    private func finish(_ transaction: Transaction) async {
        if transaction.productID == Self.productID, transaction.revocationDate == nil {
            isPro = true
        }
        await transaction.finish()
    }
}
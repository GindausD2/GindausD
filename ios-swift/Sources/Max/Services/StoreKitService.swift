import StoreKit
import Foundation

@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    static let monthlyID = "com.gindausd.max.pro.monthly"
    static let yearlyID  = "com.gindausd.max.pro.yearly"

    @Published var monthlyProduct: Product?
    @Published var yearlyProduct: Product?
    @Published var purchasedIDs: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var purchaseError: String?

    var isSubscribed: Bool { !purchasedIDs.isEmpty }

    private var transactionListener: Task<Void, Error>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.monthlyID, Self.yearlyID])
            monthlyProduct = products.first { $0.id == Self.monthlyID }
            yearlyProduct  = products.first { $0.id == Self.yearlyID }
        } catch {
            print("[StoreKit] loadProducts failed: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try verified(verification)
                await refreshEntitlements()
                await tx.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let tx = try? verified(result), tx.revocationDate == nil {
                active.insert(tx.productID)
            }
        }
        purchasedIDs = active
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let tx = try? self.verified(result) {
                    await self.refreshEntitlements()
                    await tx.finish()
                }
            }
        }
    }

    // MARK: - Verification

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.verificationFailed
        case .verified(let value): return value
        }
    }

    enum StoreError: Error { case verificationFailed }
}

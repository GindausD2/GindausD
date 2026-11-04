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

    @Published private(set) var verifiedAccountID: String?
    @Published private(set) var verifiedUntil: Date?
    var isSubscribed: Bool {
        verifiedAccountID == AuthService.shared.currentUser?.id
            && (verifiedUntil ?? .distantPast) > Date() && !purchasedIDs.isEmpty
    }
    private var refreshID = UUID()

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
            let products = try await Product.products(for: [Self.monthlyID])
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
            guard let user = AuthService.shared.currentUser, user.isDemo == false,
                  let userID = user.id,
                  let accountID = UUID(uuidString: userID) else {
                purchaseError = "Continue with Apple before subscribing."
                return
            }
            let result = try await product.purchase(options: [.appAccountToken(accountID)])
            switch result {
            case .success(let verification):
                let tx = try verified(verification)
                await refreshEntitlements()
                await tx.finish()
            case .pending:
                purchaseError = "Your purchase is pending approval."
            case .userCancelled: break
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
        let attempt = UUID(); refreshID = attempt
        let accountID = AuthService.shared.currentUser?.id
        guard let accountID, AuthService.shared.currentUser?.isDemo == false else { clearVerification(); return }
        if verifiedAccountID != accountID { clearVerification() }
        guard let proof = await signedTransactionProof() else { clearVerification(); return }
        do {
            let session = try await AuthService.shared.managedSession()
            guard let base = URL(string: kMaxAPIBaseURL), base.scheme == "https", base.host != nil else { throw URLError(.badURL) }
            var request = URLRequest(url: base.appendingPathComponent("v1/subscription"))
            request.httpMethod = "POST"; request.timeoutInterval = 45
            request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["signedTransaction": proof])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard refreshID == attempt, AuthService.shared.currentUser?.id == accountID else { return }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                clearVerification()
                purchaseError = "Your subscription couldn't be verified. Try Restore Purchases again."
                return
            }
            let value = try JSONDecoder().decode(VerifiedSubscription.self, from: data)
            guard value.active, [Self.monthlyID, Self.yearlyID].contains(value.productID),
                  let expiry = Self.parseExpiry(value.expiresAt), expiry > Date() else { throw StoreError.verificationFailed }
            purchasedIDs = [value.productID]
            verifiedAccountID = accountID; verifiedUntil = expiry; purchaseError = nil
        } catch {
            guard refreshID == attempt, AuthService.shared.currentUser?.id == accountID else { return }
            clearVerification()
            purchaseError = "Your subscription couldn't be verified. Please check your connection and try again."
        }
    }

    private func clearVerification() {
        verifiedAccountID = nil; verifiedUntil = nil; purchasedIDs = []
    }

    func signedTransactionProof() async -> String? {
        guard let user = AuthService.shared.currentUser, user.isDemo == false,
                  let userID = user.id,
              let accountID = UUID(uuidString: userID) else { return nil }
        for await result in Transaction.currentEntitlements {
            if let tx = try? verified(result), tx.revocationDate == nil,
               !tx.isUpgraded, tx.appAccountToken == accountID,
               (tx.expirationDate ?? .distantPast) > Date(),
               [Self.monthlyID, Self.yearlyID].contains(tx.productID),
               AuthService.shared.currentUser?.id == user.id {
                return result.jwsRepresentation
            }
        }
        return nil
    }

    private struct VerifiedSubscription: Decodable {
        let active: Bool
        let productID: String
        let expiresAt: String
    }
    private static func parseExpiry(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
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

    nonisolated private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.verificationFailed
        case .verified(let value): return value
        }
    }

    enum StoreError: Error { case verificationFailed }
}

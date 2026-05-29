//
//  WCSStoreKitSubscriptionManager.swift
//  WCS-Platform
//
//  StoreKit 2: product loading, purchase, restore, entitlement sync, and transaction updates.
//

import Combine
import Foundation
import StoreKit

@MainActor
final class WCSStoreKitSubscriptionManager: ObservableObject {
    static let shared = WCSStoreKitSubscriptionManager()

    /// Cached for nonisolated `User.isPremium` checks in access control.
    nonisolated static let premiumEntitlementUserDefaultsKey = "wcs.storekit.hasActivePremiumEntitlement"

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var hasActiveEntitlement = false
    @Published private(set) var activeProductIDs: Set<String> = []
    @Published var purchaseMessage: String?

    private let productIDs: Set<String>
    private var updatesTask: Task<Void, Never>?
    private var didStart = false

    init(productIDs: Set<String>? = nil) {
        self.productIDs = productIDs ?? AppEnvironment.appleSubscriptionProductIDs
    }

    /// Starts `Transaction.updates` and performs an initial entitlement sync. Safe to call repeatedly.
    func start() async {
        guard !didStart else {
            await syncEntitlements()
            return
        }
        didStart = true
        listenForTransactionUpdates()
        await loadProducts()
        await syncEntitlements()
    }

    func loadProducts() async {
        guard !productIDs.isEmpty else {
            products = []
            purchaseMessage = "No Apple subscription product IDs configured."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: productIDs)
            products = fetched.sorted { $0.displayName < $1.displayName }
            if products.isEmpty {
                purchaseMessage = "No Apple subscriptions available for this build."
            } else {
                purchaseMessage = nil
            }
        } catch {
            products = []
            purchaseMessage = "Unable to load Apple subscriptions: \(error.localizedDescription)"
        }
    }

    func purchase(product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            await handlePurchaseResult(result, product: product)
        } catch {
            purchaseMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await syncEntitlements()
            purchaseMessage = hasActiveEntitlement
                ? "Purchases restored. Premium is active on this device."
                : "No active Apple subscriptions were found for this Apple ID."
        } catch {
            purchaseMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    func handleInAppPurchaseCompletion(product: Product?, result: Result<Product.PurchaseResult, Error>) {
        Task {
            switch result {
            case .success(let purchaseResult):
                await handlePurchaseResult(purchaseResult, product: product)
            case .failure(let error):
                purchaseMessage = "Purchase failed: \(error.localizedDescription)"
            }
        }
    }

    /// Re-reads `Transaction.currentEntitlements` and updates cached premium state.
    func syncEntitlements() async {
        var entitledProductIDs: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard isTrackedProduct(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }
            entitledProductIDs.insert(transaction.productID)
        }

        activeProductIDs = entitledProductIDs
        hasActiveEntitlement = !entitledProductIDs.isEmpty
        UserDefaults.standard.set(hasActiveEntitlement, forKey: Self.premiumEntitlementUserDefaultsKey)
        NotificationCenter.default.post(name: .wcsStoreKitEntitlementsDidChange, object: nil)
    }

    func subscriptionsMatchingEntitlements() -> [Subscription] {
        guard hasActiveEntitlement else { return [] }
        let now = Date()
        return activeProductIDs.map { productID in
            let product = products.first { $0.id == productID }
            return Subscription(
                id: UUID(),
                planId: productID,
                planName: product?.displayName ?? "Premium Membership",
                status: .active,
                startDate: now,
                endDate: nil,
                price: 0
            )
        }
    }

    private func listenForTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self.syncEntitlements()
                }
            }
        }
    }

    private func handlePurchaseResult(_ result: Product.PurchaseResult, product: Product?) async {
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await syncEntitlements()
                let name = product?.displayName ?? transaction.productID
                purchaseMessage = "Purchase successful for \(name)."
                Telemetry.event(.upgradeCompleted, attributes: [
                    "provider": "apple_iap",
                    "product_id": transaction.productID,
                ])
            case .unverified:
                purchaseMessage = "Purchase could not be verified."
            }
        case .pending:
            purchaseMessage = "Purchase pending approval."
        case .userCancelled:
            purchaseMessage = "Purchase cancelled."
        @unknown default:
            purchaseMessage = "Unknown StoreKit purchase result."
        }
    }

    private func isTrackedProduct(_ id: String) -> Bool {
        productIDs.isEmpty || productIDs.contains(id)
    }
}

//
//  WCSStoreKitSubscriptionManager.swift
//  WCS-Platform
//

import Foundation
import StoreKit

@MainActor
final class WCSStoreKitSubscriptionManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published var purchaseMessage: String?

    private let productIDs: Set<String>

    init(productIDs: Set<String> = AppEnvironment.appleSubscriptionProductIDs) {
        self.productIDs = productIDs
    }

    func loadProducts() async {
        guard !productIDs.isEmpty else {
            purchaseMessage = "No Apple subscription product IDs configured."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: productIDs)
            products = fetched.sorted(by: { $0.displayName < $1.displayName })
            if products.isEmpty {
                purchaseMessage = "No Apple subscriptions available for this build."
            }
        } catch {
            purchaseMessage = "Unable to load Apple subscriptions: \(error.localizedDescription)"
        }
    }

    func purchase(product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified:
                    purchaseMessage = "Purchase successful for \(product.displayName)."
                    Telemetry.event(.upgradeCompleted, attributes: ["provider": "apple_iap", "product_id": product.id])
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
        } catch {
            purchaseMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }
}

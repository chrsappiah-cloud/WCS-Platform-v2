//
//  MembershipPaymentsHubView.swift
//  WCS-Platform
//
//  Individual Premium is sold with Apple In-App Purchase (Guideline 3.1.1).
//  Enterprise / investor flows remain external B2B procurement only.
//

import StoreKit
import SwiftUI

struct MembershipPaymentsHubView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject private var storeKitManager = WCSStoreKitSubscriptionManager.shared
    @State private var plans: [WCSSubscriptionPlan] = []
    @State private var planError: String?
    private let links = BrandOutboundLinks.current
    private let commerceRepository: CommerceRepository

    @MainActor
    init(commerceRepository: CommerceRepository = WCSAppContainer.shared.commerce) {
        self.commerceRepository = commerceRepository
    }

    var body: some View {
        List {
            Section {
                Text(
                    "Premium digital content in WCS is purchased with Apple In-App Purchase on this device. "
                        + "Restore purchases to re-enable access for an existing Apple ID subscription."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("iapComplianceNotice")
            }

            Section("Subscribe with Apple") {
                if storeKitManager.isLoading {
                    ProgressView("Loading subscription options…")
                        .accessibilityIdentifier("storeKitProductsLoading")
                } else if AppEnvironment.appleSubscriptionProductIDs.isEmpty {
                    Text("Subscription products are not configured for this build.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("storeKitProductsEmptyMessage")
                } else {
                    SubscriptionStoreView(productIDs: Array(AppEnvironment.appleSubscriptionProductIDs).sorted()) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Individual Pro")
                                .font(.headline)
                            Text("Full course access, assessments, and certificates.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .storeButton(.visible, for: .restorePurchases)
                    .onInAppPurchaseCompletion { product, result in
                        Telemetry.event(.upgradeStarted, attributes: [
                            "provider": "apple_iap",
                            "product_id": product.id,
                        ])
                        storeKitManager.handleInAppPurchaseCompletion(product: product, result: result)
                    }
                    .accessibilityIdentifier("appleSubscriptionStoreView")

                    legacyPurchaseButtonsIfNeeded

                    Button {
                        Task {
                            Telemetry.event(.upgradeStarted, attributes: ["provider": "apple_iap", "action": "restore"])
                            await storeKitManager.restorePurchases()
                        }
                    } label: {
                        Label("Restore purchases", systemImage: "arrow.clockwise")
                    }
                    .disabled(storeKitManager.isRestoring || storeKitManager.isPurchasing)
                    .accessibilityIdentifier("storeKitRestorePurchasesButton")
                }

                if let msg = storeKitManager.purchaseMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("storeKitPurchaseMessage")
                }

                if storeKitManager.hasActiveEntitlement {
                    Label("Premium is active on this Apple ID", systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("storeKitPremiumActiveBadge")
                }
            }
            .accessibilityIdentifier("appleSubscriptionsSection")

            Section("Plan overview") {
                ForEach(plans.filter { $0.segment == .individual }) { plan in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.displayName)
                                .font(.headline)
                            Spacer()
                            Text(plan.isFreeTier ? "Free" : money(plan.monthlyPriceUSD) + "/mo")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text(plan.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if plan.appleProductID != nil, !plan.isFreeTier {
                            Text("Purchased in-app with Apple In-App Purchase.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                if let planError {
                    Text(planError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Organization & investor procurement") {
                Text(
                    "Enterprise seat packs and investor programs are sold outside the app through your organization or WCS sales team. "
                        + "They do not replace Individual Pro, which must be purchased with In-App Purchase."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                if let url = links.enterpriseSalesCheckoutURL {
                    Link("Contact enterprise sales", destination: url)
                }
                if let url = links.investorRelationsPaymentURL {
                    Link("Investor relations", destination: url)
                }
            }

            #if DEBUG
            Section("Developer tools") {
                if let url = links.membershipCardCheckoutURL {
                    Link("Hosted membership checkout (debug only)", destination: url)
                }
                if let url = links.appleSubscriptionsMarketingURL {
                    Link("Apple In-App Purchase overview", destination: url)
                }
            }
            #endif

            if appViewModel.user?.isAdmin == true {
                Section("Administrator payouts") {
                    NavigationLink {
                        WCSAdminFinanceDashboardView()
                    } label: {
                        Label("Open admin finance monitor", systemImage: "banknote")
                    }
                    if let url = links.merchantFinancialDashboardURL {
                        Link("Open merchant / Connect dashboard", destination: url)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Membership")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task {
            await storeKitManager.start()
            await loadPlans()
        }
    }

    @ViewBuilder
    private var legacyPurchaseButtonsIfNeeded: some View {
        if !storeKitManager.products.isEmpty {
            ForEach(storeKitManager.products, id: \.id) { product in
                Button {
                    Task {
                        Telemetry.event(.upgradeStarted, attributes: ["provider": "apple_iap", "product_id": product.id])
                        await storeKitManager.purchase(product: product)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.displayName)
                            Text(product.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(product.displayPrice)
                    }
                }
                .disabled(storeKitManager.isPurchasing)
                .accessibilityIdentifier("storeKitPurchaseButton_\(product.id)")
            }
        }
    }

    private func loadPlans() async {
        do {
            plans = try await commerceRepository.fetchSubscriptionPlans()
            planError = nil
        } catch {
            planError = "Could not load plans: \(error.localizedDescription)"
        }
    }

    private func money(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "USD"))
    }
}

#Preview {
    NavigationStack {
        MembershipPaymentsHubView()
            .environmentObject(AppViewModel())
    }
}

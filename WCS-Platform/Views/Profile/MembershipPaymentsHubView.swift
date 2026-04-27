//
//  MembershipPaymentsHubView.swift
//  WCS-Platform
//
//  Deep-links to hosted card checkout and merchant dashboards. Card capture belongs to your PSP or StoreKit.
//

import SwiftUI
import StoreKit

struct MembershipPaymentsHubView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var storeKitManager: WCSStoreKitSubscriptionManager
    @State private var plans: [WCSSubscriptionPlan] = []
    @State private var planError: String?
    private let links = BrandOutboundLinks.current
    private let commerceRepository: CommerceRepository

    @MainActor
    init(commerceRepository: CommerceRepository = WCSAppContainer.shared.commerce) {
        self.commerceRepository = commerceRepository
        _storeKitManager = StateObject(wrappedValue: WCSStoreKitSubscriptionManager())
    }

    var body: some View {
        List {
            Section {
                Text(
                    "WCS routes learners and administrators to your payment processor (for example Stripe Checkout + Connect, or Apple In-App Purchase for eligible digital goods). "
                        + "Configure HTTPS URLs below; the app never collects raw PAN data."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Individual learner plans") {
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
                    }
                    .padding(.vertical, 2)
                }
                if let planError {
                    Text(planError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Apple subscriptions (StoreKit)") {
                if storeKitManager.isLoading {
                    ProgressView("Loading Apple products…")
                } else if storeKitManager.products.isEmpty {
                    Text("Configure `WCSAppleSubscriptionProductIDs` in Info.plist and App Store Connect products to enable in-app purchases.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
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
                    }
                }
                if let msg = storeKitManager.purchaseMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Enterprise and investor billing") {
                if let url = links.enterpriseSalesCheckoutURL {
                    Link("Open enterprise billing workflow", destination: url)
                } else {
                    Text("Set ENTERPRISE_SALES_CHECKOUT_URL for enterprise procurement.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let url = links.investorRelationsPaymentURL {
                    Link("Open investor payment workflow", destination: url)
                } else {
                    Text("Set INVESTOR_RELATIONS_PAYMENT_URL for investor commitments.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Hosted checkout and policy") {
                if let url = links.membershipCardCheckoutURL {
                    Link("Open hosted membership checkout", destination: url)
                } else {
                    Text("Set STRIPE_MEMBERSHIP_CHECKOUT_URL in the run scheme to enable card checkout in Safari.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let url = links.appleSubscriptionsMarketingURL {
                    Link("Apple In-App Purchase overview", destination: url)
                }
            }

            Section("Administrator payouts") {
                if appViewModel.user?.isAdmin == true {
                    NavigationLink {
                        WCSAdminFinanceDashboardView()
                    } label: {
                        Label("Open admin finance monitor", systemImage: "banknote")
                    }
                    if let url = links.merchantFinancialDashboardURL {
                        Link("Open merchant / Connect dashboard", destination: url)
                    } else {
                        Text("Set ADMIN_MERCHANT_DASHBOARD_URL to your Stripe (or PSP) dashboard for settlement routing.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Administrator role required to show payout and finance monitoring shortcuts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Membership & payouts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task {
            await loadPlans()
            await storeKitManager.loadProducts()
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

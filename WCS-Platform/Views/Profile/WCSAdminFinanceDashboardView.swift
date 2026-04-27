//
//  WCSAdminFinanceDashboardView.swift
//  WCS-Platform
//

import SwiftUI

struct WCSAdminFinanceDashboardView: View {
    @State private var snapshot: WCSAdminFinanceSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    private let links = BrandOutboundLinks.current

    var body: some View {
        List {
            if let snapshot {
                Section("Revenue summary") {
                    LabeledContent("Gross", value: money(snapshot.grossRevenueUSD))
                    LabeledContent("Fees", value: money(snapshot.feesUSD))
                    LabeledContent("Net", value: money(snapshot.netRevenueUSD))
                    LabeledContent("As of", value: snapshot.asOf.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Payer segments") {
                    LabeledContent("Individuals", value: money(snapshot.breakdown.individualUSD))
                    LabeledContent("Enterprise", value: money(snapshot.breakdown.enterpriseUSD))
                    LabeledContent("Investors", value: money(snapshot.breakdown.investorUSD))
                }

                Section("Active contracts") {
                    LabeledContent("Learner subscriptions", value: "\(snapshot.activeLearnerSubscriptions)")
                    LabeledContent("Enterprise contracts", value: "\(snapshot.activeEnterpriseContracts)")
                    LabeledContent("Investor commitments", value: "\(snapshot.activeInvestorCommitments)")
                }

                Section("Settlement and bank routing") {
                    LabeledContent("Pending payout", value: money(snapshot.payout.pendingUSD))
                    LabeledContent("Paid out", value: money(snapshot.payout.paidOutUSD))
                    LabeledContent("Bank destination", value: snapshot.payout.bankAccountAlias)
                    if let settled = snapshot.payout.lastSettlementAt {
                        LabeledContent("Last settlement", value: settled.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let url = links.adminBankSettlementDashboardURL {
                        Link("Open bank settlement dashboard", destination: url)
                    }
                    if let url = links.merchantFinancialDashboardURL {
                        Link("Open merchant finance dashboard", destination: url)
                    }
                }
            } else if isLoading {
                Section {
                    ProgressView("Loading finance snapshot…")
                }
            } else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Admin Finance")
        .task { await loadSnapshot() }
        .refreshable { await loadSnapshot() }
    }

    private func money(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "USD"))
    }

    private func loadSnapshot() async {
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await NetworkClient.shared.fetchAdminFinanceSnapshot()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load finance data: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        WCSAdminFinanceDashboardView()
    }
}

//
//  WCSCommerceModels.swift
//  WCS-Platform
//

import Foundation

enum WCSPayerSegment: String, Codable, CaseIterable, Hashable {
    case individual
    case enterprise
    case investor
}

struct WCSSubscriptionPlan: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let segment: WCSPayerSegment
    let isFreeTier: Bool
    let monthlyPriceUSD: Decimal
    let description: String
    let appleProductID: String?
}

struct WCSRevenueBreakdown: Codable, Hashable {
    let individualUSD: Decimal
    let enterpriseUSD: Decimal
    let investorUSD: Decimal
}

struct WCSPayoutStatus: Codable, Hashable {
    let pendingUSD: Decimal
    let paidOutUSD: Decimal
    let bankAccountAlias: String
    let lastSettlementAt: Date?
}

struct WCSAdminFinanceSnapshot: Codable, Hashable {
    let asOf: Date
    let grossRevenueUSD: Decimal
    let feesUSD: Decimal
    let netRevenueUSD: Decimal
    let activeLearnerSubscriptions: Int
    let activeEnterpriseContracts: Int
    let activeInvestorCommitments: Int
    let breakdown: WCSRevenueBreakdown
    let payout: WCSPayoutStatus
}

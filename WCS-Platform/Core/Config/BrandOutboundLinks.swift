//
//  BrandOutboundLinks.swift
//  WCS-Platform
//
//  Social, hosted checkout, and merchant dashboard URLs via environment variables (scheme / CI).
//

import Foundation

enum OutboundLinkCategory: String {
    case social
    case checkout
    case admin
    case policy
}

enum OutboundLinkPolicy {
    static let defaultAllowedHosts: Set<String> = [
        "instagram.com", "www.instagram.com",
        "tiktok.com", "www.tiktok.com",
        "facebook.com", "www.facebook.com",
        "x.com", "www.x.com", "twitter.com", "www.twitter.com",
        "youtube.com", "www.youtube.com", "youtu.be",
        "linkedin.com", "www.linkedin.com",
        "stripe.com", "dashboard.stripe.com", "checkout.stripe.com",
        "developer.apple.com"
    ]

    static var allowedHosts: Set<String> {
        let custom = ProcessInfo.processInfo.environment["WCS_ALLOWED_EXTERNAL_HOSTS"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty } ?? []
        return defaultAllowedHosts.union(custom)
    }

    static func validatedURL(_ raw: String?, category: OutboundLinkCategory) -> URL? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host?.lowercased()
        else { return nil }

        // Checkout/admin routes are stricter by default.
        if category == .checkout || category == .admin {
            return allowedHosts.contains(host) ? url : nil
        }
        return allowedHosts.contains(host) ? url : nil
    }
}

struct BrandOutboundLinks: Sendable {
    let instagramURL: URL?
    let tiktokURL: URL?
    let facebookURL: URL?
    let xURL: URL?
    let youtubeChannelURL: URL?
    let linkedInURL: URL?
    let membershipCardCheckoutURL: URL?
    let merchantFinancialDashboardURL: URL?
    let appleSubscriptionsMarketingURL: URL?

    static let current: BrandOutboundLinks = {
        func envURL(_ key: String, category: OutboundLinkCategory) -> URL? {
            OutboundLinkPolicy.validatedURL(
                ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category
            )
        }

        func fallbackSocialURL(_ raw: String) -> URL? {
            OutboundLinkPolicy.validatedURL(raw, category: .social)
        }

        return BrandOutboundLinks(
            instagramURL: envURL("SOCIAL_INSTAGRAM_URL", category: .social)
                ?? fallbackSocialURL("https://www.instagram.com/worldclassscholars"),
            tiktokURL: envURL("SOCIAL_TIKTOK_URL", category: .social)
                ?? fallbackSocialURL("https://www.tiktok.com/@worldclassscholars"),
            facebookURL: envURL("SOCIAL_FACEBOOK_URL", category: .social)
                ?? fallbackSocialURL("https://www.facebook.com/worldclassscholars"),
            xURL: envURL("SOCIAL_X_URL", category: .social)
                ?? fallbackSocialURL("https://x.com/worldclassscholar"),
            youtubeChannelURL: envURL("SOCIAL_YOUTUBE_CHANNEL_URL", category: .social)
                ?? fallbackSocialURL("https://www.youtube.com/@worldclassscholars"),
            linkedInURL: envURL("SOCIAL_LINKEDIN_URL", category: .social)
                ?? fallbackSocialURL("https://www.linkedin.com/company/worldclassscholars"),
            membershipCardCheckoutURL: envURL("STRIPE_MEMBERSHIP_CHECKOUT_URL", category: .checkout),
            merchantFinancialDashboardURL: envURL("ADMIN_MERCHANT_DASHBOARD_URL", category: .admin),
            appleSubscriptionsMarketingURL: envURL("APPLE_IAP_GUIDE_URL", category: .policy)
                ?? URL(string: "https://developer.apple.com/in-app-purchase/")
        )
    }()

    var socialPairs: [(label: String, url: URL)] {
        var out: [(String, URL)] = []
        if let instagramURL { out.append(("Instagram", instagramURL)) }
        if let tiktokURL { out.append(("TikTok", tiktokURL)) }
        if let facebookURL { out.append(("Facebook", facebookURL)) }
        if let xURL { out.append(("X", xURL)) }
        if let youtubeChannelURL { out.append(("YouTube", youtubeChannelURL)) }
        if let linkedInURL { out.append(("LinkedIn", linkedInURL)) }
        return out
    }
}

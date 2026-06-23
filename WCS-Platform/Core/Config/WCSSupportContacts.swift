//
//  WCSSupportContacts.swift
//  WCS-Platform
//
//  Activated platform support contacts for learners, admins, and App Store review.
//

import Foundation

nonisolated enum WCSSupportContacts {
    private static let primaryEmailInfoPlistKey = "WCSSupportPrimaryEmail"
    private static let secondaryEmailInfoPlistKey = "WCSSupportSecondaryEmail"
    private static let legacySupportEmailInfoPlistKey = "WCSSupportLegacyEmail"

    /// Primary support (World Class Scholars org).
    static let defaultPrimaryEmail = "christopher.appiahthompson@myworldclass.org"

    /// Secondary support (Gmail escalation).
    static let defaultSecondaryEmail = "chrsappiah@gmail.com"

    /// Legacy routing alias retained for API User-Agent and external integrations.
    static let defaultLegacyEmail = "support@wcs.education"

    static var primaryEmail: String {
        nonEmptyInfoPlist(primaryEmailInfoPlistKey) ?? defaultPrimaryEmail
    }

    static var secondaryEmail: String {
        nonEmptyInfoPlist(secondaryEmailInfoPlistKey) ?? defaultSecondaryEmail
    }

    static var legacyEmail: String {
        nonEmptyInfoPlist(legacySupportEmailInfoPlistKey) ?? defaultLegacyEmail
    }

    /// All activated support addresses (deduplicated, lowercased for comparison).
    static var activatedEmails: [String] {
        var seen = Set<String>()
        return [primaryEmail, secondaryEmail, legacyEmail].filter { email in
            let key = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { return false }
            return true
        }
    }

    static var isActivated: Bool {
        activatedEmails.contains(defaultPrimaryEmail.lowercased())
            && activatedEmails.contains(defaultSecondaryEmail.lowercased())
    }

    static var primaryMailURL: URL? {
        mailURL(for: primaryEmail)
    }

    static var secondaryMailURL: URL? {
        mailURL(for: secondaryEmail)
    }

    static var courseTeamMailURL: URL? {
        primaryMailURL
    }

    /// `mailto:primary?cc=secondary` for multi-contact outreach.
    static var combinedSupportMailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = primaryEmail
        if primaryEmail.lowercased() != secondaryEmail.lowercased() {
            components.queryItems = [URLQueryItem(name: "cc", value: secondaryEmail)]
        }
        return components.url
    }

    static var crossrefUserAgentMailto: String {
        "mailto:\(primaryEmail)"
    }

    static var displaySummary: String {
        activatedEmails.joined(separator: " · ")
    }

    private static func mailURL(for email: String) -> URL? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "mailto:\(trimmed)")
    }

    private static func nonEmptyInfoPlist(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

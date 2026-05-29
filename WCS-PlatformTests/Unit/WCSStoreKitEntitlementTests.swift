import Foundation
import Testing
@testable import WCS_Platform

struct WCSStoreKitEntitlementTests {
    @Test func userIsPremium_whenStoreKitEntitlementFlagSet() {
        let key = WCSStoreKitSubscriptionManager.premiumEntitlementUserDefaultsKey
        let prior = UserDefaults.standard.bool(forKey: key)
        defer { UserDefaults.standard.set(prior, forKey: key) }

        UserDefaults.standard.set(true, forKey: key)
        let user = TestFixtures.makeUser(subscriptions: [])
        #expect(user.isPremium)
    }

    @Test func userIsNotPremium_withoutSubscriptionOrStoreKitFlag() {
        let key = WCSStoreKitSubscriptionManager.premiumEntitlementUserDefaultsKey
        let prior = UserDefaults.standard.bool(forKey: key)
        defer { UserDefaults.standard.set(prior, forKey: key) }

        UserDefaults.standard.set(false, forKey: key)
        let user = TestFixtures.makeUser(subscriptions: [])
        #expect(!user.isPremium)
    }
}

import Foundation
import Testing
@testable import WCS_Platform

struct WCSSupportContactsTests {
    @Test
    func activatedSupportContacts_includePrimaryAndSecondary() {
        #expect(WCSSupportContacts.isActivated)
        #expect(WCSSupportContacts.primaryEmail == "christopher.appiahthompson@myworldclass.org")
        #expect(WCSSupportContacts.secondaryEmail == "chrsappiah@gmail.com")
        #expect(WCSSupportContacts.activatedEmails.count >= 2)
    }

    @Test
    func mailURLs_useActivatedAddresses() {
        #expect(WCSSupportContacts.primaryMailURL?.scheme == "mailto")
        #expect(WCSSupportContacts.secondaryMailURL?.absoluteString.contains("chrsappiah@gmail.com") == true)
        #expect(WCSSupportContacts.combinedSupportMailURL != nil)
        #expect(HomeTrustClusterContent.courseTeamMailURL != nil)
    }
}

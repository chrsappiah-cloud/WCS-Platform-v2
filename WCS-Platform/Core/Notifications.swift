//
//  Notifications.swift
//  WCS-Platform
//

import Foundation

extension Notification.Name {
    /// Posted when mock enrollments, lesson progress, or assignment submissions change so UI can refresh catalog and profile.
    static let wcsLearningStateDidChange = Notification.Name("wcs.learningState.didChange")

    /// Posted when private admin AI drafts change.
    static let wcsAdminDraftsDidChange = Notification.Name("wcs.adminDrafts.didChange")

    /// Posted when StoreKit entitlements are synced (purchase, restore, or transaction update).
    static let wcsStoreKitEntitlementsDidChange = Notification.Name("wcs.storekit.entitlements.didChange")
}

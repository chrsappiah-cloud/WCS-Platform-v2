//
//  AccessRecord.swift
//  WCS-Platform
//

import Foundation

struct AccessRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let accessLevelId: String
    let accessLevelName: String
    let status: AccessRecordStatus
    let startDate: Date
    let endDate: Date?
}

enum AccessRecordStatus: String, Codable, Hashable {
    case active
    case inactive
    case paused
}

//
//  Telemetry.swift
//  WCS-Platform
//

import Foundation
import os

nonisolated enum Telemetry {
    private static let logger = Logger(subsystem: "wcs.platform.ios", category: "telemetry")
    private static let maxStoredEvents = 200
    private static var storedEvents: [String] = []
    private static let lock = NSLock()

    static func event(_ name: String, attributes: [String: String] = [:]) {
        let payload = attributes
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = payload.isEmpty ? name : "\(name) \(payload)"
        logger.info("\(name, privacy: .public) \(payload, privacy: .public)")
        let stamped = "\(Date().formatted(date: .omitted, time: .standard)) \(line)"
        lock.lock()
        storedEvents.append(stamped)
        if storedEvents.count > maxStoredEvents {
            storedEvents.removeFirst(storedEvents.count - maxStoredEvents)
        }
        lock.unlock()
        Task { @MainActor in
            NotificationCenter.default.post(name: .wcsTelemetryDidUpdate, object: nil)
        }
    }

    static func event(_ name: String, identity: WCSIdentitySnapshot?, attributes: [String: String] = [:]) {
        var merged = attributes
        if let identity {
            for (k, v) in identity.telemetryAttributes() where merged[k] == nil {
                merged[k] = v
            }
        }
        event(name, attributes: merged)
    }

    static func recentEvents(prefix: String? = nil, limit: Int = 12) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let candidates: [String]
        if let prefix, !prefix.isEmpty {
            candidates = storedEvents.filter { $0.contains(prefix) }
        } else {
            candidates = storedEvents
        }
        return Array(candidates.suffix(max(1, limit)))
    }
}

extension Notification.Name {
    static let wcsTelemetryDidUpdate = Notification.Name("wcsTelemetryDidUpdate")
}

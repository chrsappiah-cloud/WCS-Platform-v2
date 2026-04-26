//
//  ExternalServiceResilience.swift
//  WCS-Platform
//

import Foundation
import CryptoKit

struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let baseDelayNanos: UInt64

    nonisolated static let standard = RetryPolicy(maxAttempts: 3, baseDelayNanos: 250_000_000)
}

actor CircuitBreakerRegistry {
    static let shared = CircuitBreakerRegistry()

    private struct State {
        var failures: Int = 0
        var openUntil: Date?
    }

    private var states: [String: State] = [:]
    private let threshold = 3
    private let openDuration: TimeInterval = 25

    func canExecute(service: String) -> Bool {
        let state = states[service] ?? State()
        if let openUntil = state.openUntil, openUntil > Date() {
            return false
        }
        return true
    }

    func recordSuccess(service: String) {
        states[service] = State()
    }

    func recordFailure(service: String) {
        var state = states[service] ?? State()
        state.failures += 1
        if state.failures >= threshold {
            state.openUntil = Date().addingTimeInterval(openDuration)
            state.failures = 0
        }
        states[service] = state
    }
}

actor ExternalResponseCache {
    static let shared = ExternalResponseCache()

    private struct Entry: Codable {
        let service: String
        let key: String
        let createdAt: Date
        let payload: Data
    }

    private let storageKey = "wcs.externalResponseCache"
    private var loaded = false
    private var entries: [String: Entry] = [:]

    func set(service: String, key: String, payload: Data) {
        loadIfNeeded()
        let id = idFor(service: service, key: key)
        entries[id] = Entry(service: service, key: key, createdAt: Date(), payload: payload)
        persist()
    }

    func get(service: String, key: String, maxAge: TimeInterval) -> Data? {
        loadIfNeeded()
        let id = idFor(service: service, key: key)
        guard let entry = entries[id] else { return nil }
        guard abs(entry.createdAt.timeIntervalSinceNow) <= maxAge else { return nil }
        return entry.payload
    }

    private func idFor(service: String, key: String) -> String {
        let digest = SHA256.hash(data: Data("\(service)|\(key)".utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

enum ExternalServiceResilience {
    nonisolated static func withRetry<T>(
        service: String,
        policy: RetryPolicy = .standard,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        guard await CircuitBreakerRegistry.shared.canExecute(service: service) else {
            throw URLError(.cannotConnectToHost)
        }

        var attempt = 0
        var lastError: Error?
        while attempt < policy.maxAttempts {
            do {
                let result = try await operation()
                await CircuitBreakerRegistry.shared.recordSuccess(service: service)
                return result
            } catch {
                lastError = error
                await CircuitBreakerRegistry.shared.recordFailure(service: service)
                attempt += 1
                if attempt < policy.maxAttempts {
                    let sleepNanos = policy.baseDelayNanos * UInt64(attempt)
                    try? await Task.sleep(nanoseconds: sleepNanos)
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}

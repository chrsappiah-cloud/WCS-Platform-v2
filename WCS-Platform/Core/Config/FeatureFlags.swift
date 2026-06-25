//
//  FeatureFlags.swift
//  WCS-Platform
//

import Foundation

enum FeatureFlagKey: String, CaseIterable, Codable, Sendable {
    case wcsLessonSyncV2
    case wcsLessonSyncShadowMode
    case wcsLessonSyncCanary

    var remoteKey: String {
        switch self {
        case .wcsLessonSyncV2:
            return "wcs_lesson_sync_v2"
        case .wcsLessonSyncShadowMode:
            return "wcs_lesson_sync_shadow_mode"
        case .wcsLessonSyncCanary:
            return "wcs_lesson_sync_canary"
        }
    }

    init?(wireValue: String) {
        if let key = Self(rawValue: wireValue) {
            self = key
            return
        }
        guard let key = Self.allCases.first(where: { $0.remoteKey == wireValue }) else {
            return nil
        }
        self = key
    }
}

struct FlagContext: Sendable, Equatable {
    let userId: String?
    let deviceId: String?
    let appVersion: String
    let buildChannel: String
    let locale: String
    let now: Date

    init(
        userId: String?,
        deviceId: String? = nil,
        appVersion: String,
        buildChannel: String,
        locale: String,
        now: Date
    ) {
        self.userId = userId
        self.deviceId = deviceId
        self.appVersion = appVersion
        self.buildChannel = buildChannel
        self.locale = locale
        self.now = now
    }

    static func current(
        userId: String?,
        deviceId: String? = nil,
        now: Date = Date(),
        bundle: Bundle = .main,
        locale: Locale = .current
    ) -> FlagContext {
        let info = bundle.infoDictionary ?? [:]
        return FlagContext(
            userId: userId,
            deviceId: deviceId,
            appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            buildChannel: detectBuildChannel(bundle: bundle),
            locale: locale.identifier,
            now: now
        )
    }

    private static func detectBuildChannel(bundle: Bundle) -> String {
        #if DEBUG
        return "dev"
        #else
        if bundle.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }
        return "appstore"
        #endif
    }
}

protocol FlagSource: Sendable {
    func value(for key: FeatureFlagKey, context: FlagContext) -> Bool?
}

final class FeatureFlagClient: Sendable {
    private let sources: [any FlagSource]

    init(sources: [any FlagSource]) {
        self.sources = sources
    }

    func isEnabled(_ key: FeatureFlagKey, context: FlagContext) -> Bool {
        for source in sources {
            if let value = source.value(for: key, context: context) {
                return value
            }
        }
        return false
    }

    func snapshot(context: FlagContext) -> [FeatureFlagKey: Bool] {
        Dictionary(uniqueKeysWithValues: FeatureFlagKey.allCases.map { key in
            (key, isEnabled(key, context: context))
        })
    }

    func telemetryAttributes(context: FlagContext) -> [String: String] {
        snapshot(context: context).reduce(into: [String: String]()) { result, entry in
            result["flag.\(entry.key.rawValue)"] = entry.value ? "true" : "false"
        }
    }
}

struct FeatureFlagRule: Sendable, Equatable, Decodable {
    let key: FeatureFlagKey
    let enabled: Bool
    let rolloutPercentage: Int
    let buildChannels: [String]?
    let appVersions: [String]?
    let locales: [String]?
    let userIds: [String]?
    let deviceIds: [String]?

    init(
        key: FeatureFlagKey,
        enabled: Bool,
        rolloutPercentage: Int = 100,
        buildChannels: [String]? = nil,
        appVersions: [String]? = nil,
        locales: [String]? = nil,
        userIds: [String]? = nil,
        deviceIds: [String]? = nil
    ) {
        self.key = key
        self.enabled = enabled
        self.rolloutPercentage = max(0, min(100, rolloutPercentage))
        self.buildChannels = buildChannels
        self.appVersions = appVersions
        self.locales = locales
        self.userIds = userIds
        self.deviceIds = deviceIds
    }

    enum CodingKeys: String, CodingKey {
        case key
        case enabled
        case rolloutPercentage
        case rolloutPercentageSnake = "rollout_percentage"
        case buildChannels
        case buildChannelsSnake = "build_channels"
        case appVersions
        case appVersionsSnake = "app_versions"
        case locales
        case userIds
        case userIdsSnake = "user_ids"
        case deviceIds
        case deviceIdsSnake = "device_ids"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawKey = try container.decode(String.self, forKey: .key)
        guard let key = FeatureFlagKey(wireValue: rawKey) else {
            throw DecodingError.dataCorruptedError(
                forKey: .key,
                in: container,
                debugDescription: "Unknown feature flag key \(rawKey)"
            )
        }
        self.key = key
        self.enabled = try container.decode(Bool.self, forKey: .enabled)
        let percentage = try container.decodeIfPresent(Int.self, forKey: .rolloutPercentage)
            ?? container.decodeIfPresent(Int.self, forKey: .rolloutPercentageSnake)
            ?? 100
        self.rolloutPercentage = max(0, min(100, percentage))
        self.buildChannels = try container.decodeIfPresent([String].self, forKey: .buildChannels)
            ?? container.decodeIfPresent([String].self, forKey: .buildChannelsSnake)
        self.appVersions = try container.decodeIfPresent([String].self, forKey: .appVersions)
            ?? container.decodeIfPresent([String].self, forKey: .appVersionsSnake)
        self.locales = try container.decodeIfPresent([String].self, forKey: .locales)
        self.userIds = try container.decodeIfPresent([String].self, forKey: .userIds)
            ?? container.decodeIfPresent([String].self, forKey: .userIdsSnake)
        self.deviceIds = try container.decodeIfPresent([String].self, forKey: .deviceIds)
            ?? container.decodeIfPresent([String].self, forKey: .deviceIdsSnake)
    }

    func evaluatesTrue(context: FlagContext) -> Bool {
        guard enabled else { return false }
        guard matches(buildChannels, value: context.buildChannel) else { return false }
        guard matches(appVersions, value: context.appVersion) else { return false }
        guard matchesLocale(locales, locale: context.locale) else { return false }
        guard matches(userIds, value: context.userId) else { return false }
        guard matches(deviceIds, value: context.deviceId) else { return false }
        guard rolloutPercentage > 0 else { return false }
        guard rolloutPercentage < 100 else { return true }

        let rolloutSeed = context.userId ?? context.deviceId
        guard let rolloutSeed else { return false }
        return Self.bucket(for: "\(key.rawValue):\(rolloutSeed)") < rolloutPercentage
    }

    private func matches(_ allowed: [String]?, value: String?) -> Bool {
        guard let allowed, !allowed.isEmpty else { return true }
        guard let value else { return false }
        return allowed.contains(value)
    }

    private func matchesLocale(_ allowed: [String]?, locale: String) -> Bool {
        guard let allowed, !allowed.isEmpty else { return true }
        return allowed.contains { candidate in
            locale == candidate || locale.hasPrefix("\(candidate)_") || locale.hasPrefix("\(candidate)-")
        }
    }

    static func bucket(for seed: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % 100)
    }
}

final class LocalJSONFlagSource: FlagSource {
    private let rules: [FeatureFlagKey: FeatureFlagRule]

    init(rules: [FeatureFlagRule]) {
        self.rules = Dictionary(uniqueKeysWithValues: rules.map { ($0.key, $0) })
    }

    convenience init(data: Data, decoder: JSONDecoder = JSONDecoder()) throws {
        let payload = try decoder.decode(FeatureFlagDefaultsPayload.self, from: data)
        self.init(rules: payload.flags)
    }

    convenience init(bundle: Bundle = .main, resourceName: String = "FeatureFlagDefaults") {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(FeatureFlagDefaultsPayload.self, from: data) else {
            self.init(rules: [])
            return
        }
        self.init(rules: payload.flags)
    }

    func value(for key: FeatureFlagKey, context: FlagContext) -> Bool? {
        rules[key]?.evaluatesTrue(context: context)
    }
}

final class RemoteConfigFlagSource: FlagSource, @unchecked Sendable {
    private let lock = NSLock()
    private var rules: [FeatureFlagKey: FeatureFlagRule]

    init(rules: [FeatureFlagRule] = []) {
        self.rules = Dictionary(uniqueKeysWithValues: rules.map { ($0.key, $0) })
    }

    func replaceRules(_ rules: [FeatureFlagRule]) {
        lock.withLock {
            self.rules = Dictionary(uniqueKeysWithValues: rules.map { ($0.key, $0) })
        }
    }

    func value(for key: FeatureFlagKey, context: FlagContext) -> Bool? {
        lock.withLock {
            rules[key]?.evaluatesTrue(context: context)
        }
    }
}

final class DebugFlagSource: FlagSource, @unchecked Sendable {
    private let lock = NSLock()
    private var overrides: [FeatureFlagKey: Bool]

    init(overrides: [FeatureFlagKey: Bool] = [:]) {
        self.overrides = overrides
    }

    func setOverride(_ value: Bool, for key: FeatureFlagKey) {
        lock.withLock { overrides[key] = value }
    }

    func clearOverride(for key: FeatureFlagKey) {
        lock.withLock { overrides[key] = nil }
    }

    func clearAll() {
        lock.withLock { overrides.removeAll() }
    }

    func value(for key: FeatureFlagKey, context: FlagContext) -> Bool? {
        lock.withLock { overrides[key] }
    }
}

struct LessonSyncFeatureState: Sendable, Equatable {
    let usesV2: Bool
    let shadowMode: Bool
    let canary: Bool
}

struct LessonSyncFeatureGate: Sendable {
    let flags: FeatureFlagClient

    init(flags: FeatureFlagClient) {
        self.flags = flags
    }

    func state(context: FlagContext) -> LessonSyncFeatureState {
        let canary = flags.isEnabled(.wcsLessonSyncCanary, context: context)
        let usesV2 = canary && flags.isEnabled(.wcsLessonSyncV2, context: context)
        return LessonSyncFeatureState(
            usesV2: usesV2,
            shadowMode: canary && flags.isEnabled(.wcsLessonSyncShadowMode, context: context),
            canary: canary
        )
    }
}

private struct FeatureFlagDefaultsPayload: Decodable {
    let flags: [FeatureFlagRule]
}

import Foundation
import Testing
@testable import WCS_Platform

struct FeatureFlagClientTests {
    @Test
    func localJSONDefaults_keepLessonSyncFlagsOff() throws {
        let source = try LocalJSONFlagSource(data: Data(Self.defaultJSON.utf8))
        let client = FeatureFlagClient(sources: [source])

        #expect(client.isEnabled(.wcsLessonSyncV2, context: Self.context) == false)
        #expect(client.isEnabled(.wcsLessonSyncShadowMode, context: Self.context) == false)
        #expect(client.isEnabled(.wcsLessonSyncCanary, context: Self.context) == false)
    }

    @Test
    func sourceOrder_allowsDebugOverrideToWin() {
        let debug = DebugFlagSource(overrides: [.wcsLessonSyncV2: true])
        let local = LocalJSONFlagSource(rules: [
            FeatureFlagRule(key: .wcsLessonSyncV2, enabled: false)
        ])
        let client = FeatureFlagClient(sources: [debug, local])

        #expect(client.isEnabled(.wcsLessonSyncV2, context: Self.context) == true)
    }

    @Test
    func remoteConfigSource_canUpdateRulesInMemory() {
        let remote = RemoteConfigFlagSource()
        let client = FeatureFlagClient(sources: [remote])

        #expect(client.isEnabled(.wcsLessonSyncCanary, context: Self.context) == false)

        remote.replaceRules([
            FeatureFlagRule(key: .wcsLessonSyncCanary, enabled: true, rolloutPercentage: 100)
        ])

        #expect(client.isEnabled(.wcsLessonSyncCanary, context: Self.context) == true)
    }

    @Test
    func rolloutPercentage_usesDeterministicUserBucket() {
        let source = LocalJSONFlagSource(rules: [
            FeatureFlagRule(key: .wcsLessonSyncCanary, enabled: true, rolloutPercentage: 1)
        ])
        let client = FeatureFlagClient(sources: [source])
        let user = Self.firstUserMatchingBucket(lessThan: 1)
        let includedContext = FlagContext(
            userId: user,
            appVersion: "1.0",
            buildChannel: "testflight",
            locale: "en_US",
            now: Date(timeIntervalSince1970: 0)
        )

        #expect(client.isEnabled(.wcsLessonSyncCanary, context: includedContext) == true)
        #expect(FeatureFlagRule.bucket(for: "wcsLessonSyncCanary:\(user)") == 0)
    }

    @Test
    func buildChannelFilter_preventsAppStoreFromUsingPreProdFlag() {
        let source = LocalJSONFlagSource(rules: [
            FeatureFlagRule(
                key: .wcsLessonSyncShadowMode,
                enabled: true,
                rolloutPercentage: 100,
                buildChannels: ["dev", "testflight"]
            )
        ])
        let client = FeatureFlagClient(sources: [source])
        let appStoreContext = FlagContext(
            userId: "user-1",
            appVersion: "1.0",
            buildChannel: "appstore",
            locale: "en_US",
            now: Date(timeIntervalSince1970: 0)
        )

        #expect(client.isEnabled(.wcsLessonSyncShadowMode, context: appStoreContext) == false)
    }

    @Test
    func lessonSyncGate_requiresCanaryBeforeUsingV2OrShadowMode() {
        let flags = FeatureFlagClient(sources: [
            LocalJSONFlagSource(rules: [
                FeatureFlagRule(key: .wcsLessonSyncV2, enabled: true),
                FeatureFlagRule(key: .wcsLessonSyncShadowMode, enabled: true),
                FeatureFlagRule(key: .wcsLessonSyncCanary, enabled: false),
            ])
        ])
        let gate = LessonSyncFeatureGate(flags: flags)

        #expect(gate.state(context: Self.context) == LessonSyncFeatureState(
            usesV2: false,
            shadowMode: false,
            canary: false
        ))
    }

    private static let context = FlagContext(
        userId: "user-1",
        appVersion: "1.0",
        buildChannel: "testflight",
        locale: "en_US",
        now: Date(timeIntervalSince1970: 0)
    )

    private static let defaultJSON = """
    {
      "flags": [
        { "key": "wcs_lesson_sync_v2", "enabled": false, "rollout_percentage": 0 },
        { "key": "wcs_lesson_sync_shadow_mode", "enabled": false, "rollout_percentage": 0 },
        { "key": "wcs_lesson_sync_canary", "enabled": false, "rollout_percentage": 0 }
      ]
    }
    """

    private static func firstUserMatchingBucket(lessThan percentage: Int) -> String {
        for index in 0..<1_000 {
            let user = "user-\(index)"
            if FeatureFlagRule.bucket(for: "wcsLessonSyncCanary:\(user)") < percentage {
                return user
            }
        }
        Issue.record("Expected to find a stable rollout bucket.")
        return "user-0"
    }
}

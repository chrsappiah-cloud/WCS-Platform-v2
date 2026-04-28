//
//  WCS_PlatformTests.swift
//  WCS-PlatformTests
//
//  Created by Christopher Appiah-Thompson  on 25/4/2026.
//

import Testing
import Foundation
@testable import WCS_Platform

@Suite(.serialized)
struct WCS_PlatformTests {

    @Test func publishedAIDraftHasStructuredBriefAndReport() async throws {
        await MockLearningStore.shared.deleteBlockedAICourses()
        await MockLearningStore.shared.publishDraftToCatalog(makeDraftForTests(
            title: "AI Business Operator",
            summary: "AI-generated draft for administrators only. Includes module video lessons plus course materials from open-source references for internal review before publication.",
            outcomePrefix: "Build real AI operating workflows",
            includeFindings: true
        ))

        let courses = await MockLearningStore.shared.snapshotCourses(forPremiumUser: true)
        guard let published = courses.first(where: { $0.title == "AI Business Operator" }) else {
            #expect(Bool(false), "Published draft course should exist in catalog.")
            return
        }

        #expect(published.description.contains("Course design goals:"))
        #expect(published.description.contains("Module overview:"))
        #expect(published.description.contains("Learning outcomes:"))
        #expect(published.courseReport != nil)
        #expect((published.courseReport?.learningOutcomes.count ?? 0) > 0)
    }

    @Test func publishGuardBlocksQuestionStyleOutput() async throws {
        let store = AdminCourseDraftStore(generator: StubQuestionGenerator())
        let prompt = """
        Build a WCS AI Course Generation blueprint using a retrieval-plan-generate workflow.
        Product name: What is AI?
        Ideal learner: general users
        Transformation promise: understand AI
        Offer stack: modules and quizzes
        Launch angle: awareness
        Additional curriculum and brand notes: none
        """

        let generated = try await store.generate(prompt: prompt, createdBy: "admin@wcs", accessTier: .freePublic)
        #expect(generated.title.lowercased().contains("what is"))

        await #expect(throws: Error.self) {
            try await store.markPublished(generated.id)
        }
    }

    @Test func publishGuard_allowsHowToStyleAITitlesWhenStructured() async throws {
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        defer {
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
        }
        UserDefaults.standard.set(UserRole.orgAdmin.rawValue, forKey: "wcs.mockRole")

        let store = AdminCourseDraftStore(generator: StubTitledPublishableGenerator(title: "How to Lead Remote Teams"))
        let generated = try await store.generate(
            prompt: "Build a WCS AI Course Generation blueprint using a retrieval-plan-generate workflow.\nProduct name: How to Lead Remote Teams\nIdeal learner: managers\nTransformation promise: execution\nOffer stack: modules\nLaunch angle: growth\nAdditional curriculum and brand notes: none\n",
            createdBy: "admin@wcs",
            accessTier: .freePublic
        )
        #expect(generated.title.lowercased().contains("how to"))
        try await store.markPublished(generated.id)
        let draftsAfter = await store.allDrafts()
        #expect(draftsAfter.first(where: { $0.id == generated.id })?.status == .published)
    }

    @Test func publishGuard_manualBackupAllowsHowToInCourseTitle() async throws {
        await AdminCourseDraftStore.shared.clearAll()
        await MockLearningStore.shared.deleteBlockedAICourses()
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        let previousAdminMode = UserDefaults.standard.bool(forKey: "wcs.mockAdminMode")
        defer {
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
            UserDefaults.standard.set(previousAdminMode, forKey: "wcs.mockAdminMode")
        }
        UserDefaults.standard.set(UserRole.orgAdmin.rawValue, forKey: "wcs.mockRole")
        UserDefaults.standard.set(true, forKey: "wcs.mockAdminMode")

        let videoURL = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
        let draft = try await AdminCourseDraftStore.shared.createManualBackupDraft(
            createdBy: "admin@wcs",
            accessTier: .freePublic,
            courseTitle: "How to Study Effectively (Manual)",
            summary: "A practical manual backup with common “how to” phrasing in the title.",
            moduleTitle: "Week 1",
            videoTitle: "Lecture",
            videoURL: videoURL,
            readingTitle: "Reading",
            readingMaterial: "Notes.",
            quizTitle: "Quiz",
            quizPrompt: "Q1",
            assignmentTitle: "Assignment",
            assignmentBrief: "Brief."
        )
        try await AdminCourseDraftStore.shared.markPublished(draft.id)
        let published = await MockLearningStore.shared.snapshotCourse(draft.id)
        #expect(published?.title.contains("How to") == true)
    }

    @Test func publishedDraftVideoLessonsResolvePlaybackURLs() async throws {
        await MockLearningStore.shared.deleteBlockedAICourses()
        let draft = makeDraftForTests(
            title: "AI Video Rendering Validation",
            summary: "Validate that all module video lessons resolve playback URLs.",
            outcomePrefix: "Render playable module videos",
            includeFindings: true
        )

        await MockLearningStore.shared.publishDraftToCatalog(draft)

        // Video assets are applied asynchronously; poll for completion.
        let deadline = Date().addingTimeInterval(8)
        var latestCourse: Course?
        while Date() < deadline {
            if let course = await MockLearningStore.shared.snapshotCourse(draft.id) {
                latestCourse = course
                let videoLessons = course.modules.flatMap(\.lessons).filter { $0.type == .video }
                let allResolved = !videoLessons.isEmpty && videoLessons.allSatisfy {
                    guard let url = $0.videoURL else { return false }
                    return url.hasPrefix("http")
                }
                if allResolved { break }
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }

        guard let course = latestCourse else {
            #expect(Bool(false), "Published course should be retrievable for video validation.")
            return
        }

        let videoLessons = course.modules.flatMap(\.lessons).filter { $0.type == .video }
        #expect(!videoLessons.isEmpty, "Expected at least one video lesson in generated module structure.")
        #expect(videoLessons.allSatisfy { ($0.videoURL ?? "").hasPrefix("http") })
        #expect(videoLessons.allSatisfy { ($0.subtitle ?? "").isEmpty == false })
    }

    @Test func generatedVideoAssetsContainModuleMediaMetadata() async throws {
        let draft = makeDraftForTests(
            title: "AI Media Metadata Validation",
            summary: "Validate script segments, YouTube companion hints, and audio readiness metadata.",
            outcomePrefix: "Verify media metadata quality",
            includeFindings: false
        )
        let generator = MockAIVideoGenerator()
        let generated = await generator.generateVideoAssets(for: draft) { _ in }

        #expect(!generated.isEmpty, "Expected generated video assets for video lessons.")

        for asset in generated.values {
            #expect((asset.youtubeCompanionURL ?? "").contains("youtube.com/results"))
            #expect(!(asset.youtubeSearchKeywords ?? []).isEmpty)
            #expect(!(asset.moduleScriptSegments ?? []).isEmpty)
            #expect((asset.tutorialNarrationText ?? "").contains("World Class Scholars"))
            #expect(!(asset.microphoneChecklist ?? []).isEmpty)
            #expect((asset.audioSystemStatus ?? "").isEmpty == false)
            #expect(
                (asset.openAIRecommendedPipeline ?? []).contains(where: { $0.contains("/v1/videos") })
            )
            #expect(
                (asset.openAIRecommendedPipeline ?? []).contains(where: { $0.contains("/v1/audio/speech") })
            )
        }
    }

    @Test func scriptLinesCoverVideoLessonsInOrder() async throws {
        await MockLearningStore.shared.deleteBlockedAICourses()
        let draft = makeDraftForTests(
            title: "Script Line Coverage",
            summary: "Ensure pipeline sees video lessons.",
            outcomePrefix: "Learn",
            includeFindings: false
        )
        await MockLearningStore.shared.publishDraftToCatalog(draft)

        guard let course = await MockLearningStore.shared.snapshotCourse(draft.id) else {
            Issue.record("Expected published course.")
            return
        }

        let lines = ModuleVideoDiscoveryPipeline.scriptLines(from: course)
        let videoLessonCount = course.modules.flatMap(\.lessons).filter { $0.type == .video }.count
        #expect(lines.count == videoLessonCount)
        #expect(!lines.isEmpty)
        #expect(lines.first?.youTubeSearchQuery.contains(course.title) == true)
    }

    @Test func youTubeQuerySynthesis_isFastAtScale() {
        let course = Course(
            id: UUID(),
            title: "World Class Scholars Bootcamp",
            subtitle: nil,
            description: "Learning outcomes: a | b",
            thumbnailURL: "https://example.com/t.jpg",
            coverURL: nil,
            durationSeconds: 3600,
            price: nil,
            isEnrolled: true,
            isOwned: true,
            isUnlockedBySubscription: false,
            rating: nil,
            reviewCount: 0,
            organizationName: "WCS",
            level: "Beginner",
            effortDescription: nil,
            spokenLanguages: ["en"],
            modules: [
                Module(
                    id: UUID(),
                    title: "Foundations",
                    description: nil,
                    order: 0,
                    isAvailable: true,
                    isUnlocked: true,
                    lessons: [
                        Lesson(
                            id: UUID(),
                            title: "Welcome",
                            subtitle: "Orientation",
                            type: .video,
                            videoURL: "https://example.com/v.mp4",
                            durationSeconds: 120,
                            isCompleted: false,
                            isAvailable: true,
                            isUnlocked: true,
                            reading: nil,
                            quiz: nil,
                            assignment: nil,
                            captionTracks: [],
                            serverResumePositionSeconds: nil
                        )
                    ]
                )
            ],
            courseReport: nil
        )

        let lines = ModuleVideoDiscoveryPipeline.scriptLines(from: course)
        let iterations = 3_000
        let t0 = CFAbsoluteTimeGetCurrent()
        for _ in 0 ..< iterations {
            for line in lines {
                _ = line.youTubeSearchQuery
            }
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        #expect(elapsed < 0.2, "Local query synthesis should stay interactive; saw \(elapsed)s")
    }

    @Test func youTubeSearch_singleProbe_skipsWithoutKey() async throws {
        guard YouTubeSearchAPIClient.resolveAPIKey() != nil else {
            return
        }
        let t0 = CFAbsoluteTimeGetCurrent()
        let page: YouTubeSearchPage
        do {
            page = try await YouTubeSearchAPIClient.searchVideos(
                query: "online learning platform lecture",
                maxResults: 2
            )
        } catch let YouTubeAPIError.httpStatus(code, message)
            where code == 400 && (message?.localizedCaseInsensitiveContains("API key not valid") ?? false) {
            // Treat invalid scheme key as "missing key" in CI/dev environments.
            return
        } catch {
            // Network/API flakiness should not fail this optional probe.
            return
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        #expect(elapsed < 25)
        #expect(page.items.count <= 2)
    }

    @Test func manualBackupDraft_createRejectsNonHTTPSVideoURL() async throws {
        await AdminCourseDraftStore.shared.clearAll()
        do {
            _ = try await AdminCourseDraftStore.shared.createManualBackupDraft(
                createdBy: "admin@wcs",
                accessTier: .freePublic,
                courseTitle: "Bad URL Course",
                summary: "Summary.",
                moduleTitle: "Module",
                videoTitle: "Video",
                videoURL: "http://insecure.example.com/a.mp4",
                readingTitle: "Reading",
                readingMaterial: "Body.",
                quizTitle: "Quiz",
                quizPrompt: "Q?",
                assignmentTitle: "Assignment",
                assignmentBrief: "Brief."
            )
            Issue.record("Expected createManualBackupDraft to reject non-https video URL.")
        } catch let error as NSError {
            #expect(error.domain == "WCSAdminAI")
            #expect(error.code == 1105)
        }
    }

    @Test func manualBackupDraft_publishesWithManualVideoAndLearningArtifacts() async throws {
        await AdminCourseDraftStore.shared.clearAll()
        await MockLearningStore.shared.deleteBlockedAICourses()

        let previousAdminMode = UserDefaults.standard.bool(forKey: "wcs.mockAdminMode")
        defer { UserDefaults.standard.set(previousAdminMode, forKey: "wcs.mockAdminMode") }
        UserDefaults.standard.set(true, forKey: "wcs.mockAdminMode")

        let manualVideoURL = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
        let draft = try await AdminCourseDraftStore.shared.createManualBackupDraft(
            createdBy: "admin@wcs",
            accessTier: .freePublic,
            courseTitle: "Manual Continuity Course",
            summary: "Manual backup package for automation outages.",
            moduleTitle: "Continuity Module",
            videoTitle: "Manual lecture upload",
            videoURL: manualVideoURL,
            readingTitle: "Manual reading pack",
            readingMaterial: "Core references and facilitator notes.",
            quizTitle: "Manual quiz set",
            quizPrompt: "Q1/Q2/Q3",
            assignmentTitle: "Manual assignment brief",
            assignmentBrief: "Submit an implementation memo."
        )

        try await AdminCourseDraftStore.shared.markPublished(draft.id)
        guard let published = await MockLearningStore.shared.snapshotCourse(draft.id) else {
            Issue.record("Expected published manual backup course.")
            return
        }

        let lessons = published.modules.flatMap(\.lessons)
        #expect(lessons.contains(where: { $0.type == .video }))
        #expect(lessons.contains(where: { $0.type == .reading }))
        #expect(lessons.contains(where: { $0.type == .quiz }))
        #expect(lessons.contains(where: { $0.type == .assignment }))
        #expect(lessons.first(where: { $0.type == .video })?.videoURL == manualVideoURL)
    }

    @Test func crossrefDecode_handlesEmptyPayload() throws {
        let data = Data(#"{"message":{"items":[]}}"#.utf8)
        let works = try CrossrefWorksAPIClient.decodeWorks(from: data)
        #expect(works.isEmpty)
    }

    @Test func youTubeDecode_handlesMinimalPayload() throws {
        let data = Data(
            #"{"items":[{"id":{"videoId":"dQw4w9WgXcQ"},"snippet":{"title":"Learning Demo","thumbnails":{"medium":{"url":"https://img.youtube.com/vi/dQw4w9WgXcQ/mqdefault.jpg"}}}}],"nextPageToken":"abc"}"#.utf8
        )
        let page = try YouTubeSearchAPIClient.decodePage(from: data)
        #expect(page.items.count == 1)
        #expect(page.items[0].videoID == "dQw4w9WgXcQ")
    }

    @Test func youTubeSearch_rejectsInvalidQueryBeforeNetwork() async throws {
        do {
            _ = try await YouTubeSearchAPIClient.searchVideos(
                query: "   \n\t   ",
                maxResults: 2
            )
            #expect(Bool(false), "Expected invalid query to throw before network call.")
        } catch let error as YouTubeAPIError {
            switch error {
            case .invalidQuery:
                #expect(true)
            default:
                #expect(Bool(false), "Expected .invalidQuery, got \(error).")
            }
        }
    }

    @Test func outboundLinkPolicy_blocksUnknownHosts() {
        let blocked = OutboundLinkPolicy.validatedURL("https://evil.example/phish", category: .social)
        #expect(blocked == nil)
    }

    @Test func domainContracts_haveStrictSingleOwnership() {
        let errors = WCSDomainRegistry.validateStrictOwnership()
        #expect(errors.isEmpty, "Domain ownership must be strict and non-overlapping. Errors: \(errors)")
        #expect(WCSDomainRegistry.owner(of: .organizationMembership) == .identity)
        #expect(WCSDomainRegistry.owner(of: .programs) == .catalog)
        #expect(WCSDomainRegistry.owner(of: .entitlements) == .commerce)
        #expect(WCSDomainRegistry.owner(of: .modulePublishing) == .contentOps)
        #expect(WCSDomainRegistry.owner(of: .completionMetrics) == .analytics)
    }

    @Test func identity_supportsLearnerInstructorAndOrgAdminRoles() async throws {
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        defer {
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
        }

        UserDefaults.standard.set(UserRole.instructor.rawValue, forKey: "wcs.mockRole")
        let instructor = await MockLearningStore.shared.currentUser()
        #expect(instructor.role == .instructor)
        #expect(instructor.isInstructor)
        #expect(!instructor.memberships.isEmpty)
        #expect(instructor.activeOrganizationId != nil)

        UserDefaults.standard.set(UserRole.orgAdmin.rawValue, forKey: "wcs.mockRole")
        let orgAdmin = await MockLearningStore.shared.currentUser()
        #expect(orgAdmin.role == .orgAdmin)
        #expect(orgAdmin.isAdmin)
        #expect(orgAdmin.memberships.contains(where: { $0.isActive }))
    }

    @Test func commerce_paidProgramBlockedWithoutEntitlement() async throws {
        let paid = MockCourseCatalog.courses.first(where: { $0.price != nil })
        #expect(paid != nil)
        guard let paid else { return }

        let user = User(
            id: UUID(),
            email: "learner@wcs.test",
            name: "Learner",
            photoURL: nil,
            role: .learner,
            activeOrganizationId: nil,
            memberships: [],
            subscriptions: [],
            enrollments: []
        )

        let allowed = NetworkClient.shared.canAccessProgram(paid, user: user)
        #expect(!allowed, "Paid programs should require entitlement.")
    }

    @Test func communityAnchoredThread_requiresLearningAccess() async throws {
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        let previousPremium = UserDefaults.standard.bool(forKey: "wcs.mockPremiumMode")
        defer {
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
            UserDefaults.standard.set(previousPremium, forKey: "wcs.mockPremiumMode")
        }

        UserDefaults.standard.set(UserRole.learner.rawValue, forKey: "wcs.mockRole")
        UserDefaults.standard.set(false, forKey: "wcs.mockPremiumMode")
        await MockLearningStore.shared.resetLearningStateForTests()

        await #expect(throws: Error.self) {
            _ = try await NetworkClient.shared.createDiscussionPost(
                topicID: "wcs:anchor:course:10000000-0000-0000-0000-000000000001:module:20000000-0000-0000-0000-000000000001:lesson:30000000-0000-0000-0000-000000000001",
                body: "Trying to post without enrollment",
                authorName: "Learner"
            )
        }
    }

    @Test func contentOpsPublish_requiresOrgAdminRole() async throws {
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        defer {
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
        }

        let store = AdminCourseDraftStore(generator: StubPublishableGenerator())
        let generated = try await store.generate(
            prompt: """
            Build a structured AI operator curriculum.
            """,
            createdBy: "admin@wcs",
            accessTier: .freePublic
        )

        UserDefaults.standard.set(UserRole.learner.rawValue, forKey: "wcs.mockRole")
        await #expect(throws: Error.self) {
            try await store.markPublished(generated.id)
        }
    }

    @Test func commerceAdminFinance_requiresAdminRole() async throws {
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        defer {
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
        }

        UserDefaults.standard.set(UserRole.learner.rawValue, forKey: "wcs.mockRole")
        await #expect(throws: Error.self) {
            _ = try await NetworkClient.shared.fetchAdminFinanceSnapshot()
        }
    }

    @Test func commerceAdminFinance_allowsOrgAdminRole() async throws {
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        defer {
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
        }

        UserDefaults.standard.set(UserRole.orgAdmin.rawValue, forKey: "wcs.mockRole")
        let snapshot = try await NetworkClient.shared.fetchAdminFinanceSnapshot()
        #expect(snapshot.netRevenueUSD >= 0)
        #expect(!snapshot.payout.bankAccountAlias.isEmpty)
    }

    @Test func commercePlans_areAvailableToAuthenticatedLearner() async throws {
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        defer {
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
        }

        UserDefaults.standard.set(UserRole.learner.rawValue, forKey: "wcs.mockRole")
        let plans = try await NetworkClient.shared.fetchSubscriptionPlans()
        #expect(!plans.isEmpty)
        #expect(plans.contains(where: { $0.segment == .individual }))
    }

    @Test func domainProjections_coverAllBoundedContextParameters() async throws {
        UserDefaults.standard.set(UserRole.orgAdmin.rawValue, forKey: "wcs.mockRole")
        let user = await MockLearningStore.shared.currentUser()
        let course = MockCourseCatalog.courses[0]
        let identity = WCSDomainProjector.identity(from: user)
        #expect(identity.role == .orgAdmin)
        #expect(identity.activeOrganizationId != nil)
        #expect(!identity.memberships.isEmpty)

        let catalog = WCSDomainProjector.catalog(from: course, tags: ["featured", "career"], featuredPlacement: 1)
        #expect(catalog.tags.contains("featured"))
        #expect(catalog.featuredPlacement == 1)

        let learning = WCSDomainProjector.learning(from: course, enrollment: nil)
        #expect(learning.estimatedWeeklyHours >= 1)
        #expect(learning.assessmentCount >= 1)
        #expect(!learning.completionRule.isEmpty)

        let feed = await MockDiscussionStore.shared.feed(topicID: nil)
        let community = WCSDomainProjector.community(topics: feed.topics, posts: feed.posts)
        #expect(!community.isEmpty)
        #expect(community.allSatisfy { $0.moderationEnabled && $0.reportingEnabled })

        let commerce = WCSDomainProjector.commerce(from: course, user: user)
        #expect(!commerce.sku.isEmpty)

        let profile = WCSDomainProjector.profile(from: user)
        #expect(profile.completedCourseCount >= 0)

        let draft = makeDraftForTests(
            title: "Projection Draft",
            summary: "Domain projection check.",
            outcomePrefix: "Validate bounded contexts",
            includeFindings: true
        )
        let contentOps = WCSDomainProjector.contentOps(from: draft)
        #expect(contentOps.moduleCount > 0)
        #expect(contentOps.publishable)

        let analytics = WCSDomainProjector.analytics(
            from: [
                "course.load.success",
                "lesson.video.playback.heartbeat",
                "profile.milestone.certificate_earned",
                "subscription.renewed"
            ]
        )
        #expect(analytics.funnelEvents >= 1)
        #expect(analytics.retentionSignals >= 1)
        #expect(analytics.completionSignals >= 1)
        #expect(analytics.monetizationSignals >= 1)
    }

    @Test func homeDiscover_trustCluster_contentContract() {
        #expect(HomeTrustClusterContent.learnerTestimonialPages.count == 3)
        #expect(HomeTrustClusterContent.learnerTestimonialPages.allSatisfy { !$0.quote.isEmpty && !$0.name.isEmpty && !$0.role.isEmpty })
        #expect(HomeTrustClusterContent.courseTeamMailURL != nil)
        #expect(HomeTrustClusterContent.supportEmail.contains("@"))
        #expect(HomeTrustClusterContent.designerName.contains("Christopher"))
        let first = HomeTrustClusterContent.learnerTestimonialPages[0]
        #expect(first.quote.localizedCaseInsensitiveContains("creative arts"))
        #expect(first.quote.localizedCaseInsensitiveContains("dementia"))
    }

    @Test func homeDiscover_trustCluster_linkedInStoriesURL_isAllowlisted() {
        let url = BrandOutboundLinks.current.linkedInURL
        #expect(url != nil)
        let host = url!.host?.lowercased() ?? ""
        #expect(host.contains("linkedin"))
    }

    @Test func lessonVideoPlaybackPolicy_detectsAppleSampleHLS() throws {
        let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!
        #expect(LessonVideoPlaybackPolicy.isHLSStreamURL(url))
    }

    @Test func lessonVideoPlaybackPolicy_plainMp4IsNotHLS() throws {
        let url = URL(string: "https://example.com/media/trailer.mp4")!
        #expect(!LessonVideoPlaybackPolicy.isHLSStreamURL(url))
    }

    @Test func lessonVideoRenderJobListResponse_decodesFromEdgeShape() throws {
        let json = """
        {"jobs":[{"id":"550e8400-e29b-41d4-a716-446655440000","course_id":"c1","module_id":"m1","lesson_id":"l1","pipeline_mode":"scene_orchestration_v1","provider":"mock","status":"completed","playback_url":"https://example.com/a.mp4","error_message":null,"client_app_version":"1.0","created_at":"2026-04-28T00:00:00Z","generation_prompt_excerpt":"hook"}]}
        """
        let decoded = try JSONDecoder().decode(LessonVideoRenderJobListResponse.self, from: Data(json.utf8))
        #expect(decoded.jobs.count == 1)
        #expect(decoded.jobs[0].status == "completed")
        #expect(decoded.jobs[0].normalizedStatus == .completed)
        #expect(decoded.jobs[0].provider == "mock")
        #expect(decoded.jobs[0].playbackUrl?.contains("example.com") == true)
    }

    @Test func lessonVideoRenderJobStatus_normalizesWorkflowAliases() {
        #expect(LessonVideoRenderJobStatus.normalized(from: "inprogress") == .inProgress)
        #expect(LessonVideoRenderJobStatus.normalized(from: "running") == .inProgress)
        #expect(LessonVideoRenderJobStatus.normalized(from: "ready_for_composition") == .readyForComposition)
        #expect(LessonVideoRenderJobStatus.normalized(from: "succeeded") == .completed)
        #expect(LessonVideoRenderJobStatus.normalized(from: "unknown_state") == nil)
    }

    @Test func lessonVideoStoryboard_encodesForBFFPayload() throws {
        let scene = LessonVideoScenePlan(
            sceneId: "scene-1",
            learningObjective: "Define overfitting",
            narrationText: "Overfitting means the model memorizes training noise.",
            visualPrompt: "Clean motion graphic, chart axis labels legible",
            shotType: "explain",
            durationSeconds: 12,
            onScreenText: "Overfitting",
            referenceImageURL: nil,
            needsDiagram: true,
            assessmentCheckpoint: "Name one symptom of overfitting."
        )
        let board = LessonVideoStoryboard(
            storyboardId: "sb-test",
            pipelineVersion: "scene_orchestration_v1",
            moduleId: "m1",
            moduleTitle: "Foundations",
            lessonId: "l1",
            lessonTitle: "Bias vs variance",
            scenes: [scene],
            masterVisualPrompt: "Educational 16:9 module intro"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(board)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"sceneId\":\"scene-1\""))
        #expect(json.contains("\"scenes\""))
        let decoded = try JSONDecoder().decode(LessonVideoStoryboard.self, from: data)
        #expect(decoded.scenes.count == 1)
        #expect(decoded.scenes[0].needsDiagram == true)
    }

    @Test func lessonVideoPlaybackPolicy_nativeHttpsExcludesYouTube() throws {
        let mp4 = URL(string: "https://storage.example.co/object/sign/lesson.mp4?token=abc")!
        #expect(LessonVideoPlaybackPolicy.isNativeAVPlayerHTTPSURL(mp4))
        let hls = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!
        #expect(LessonVideoPlaybackPolicy.isNativeAVPlayerHTTPSURL(hls))
        let yt = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!
        #expect(!LessonVideoPlaybackPolicy.isNativeAVPlayerHTTPSURL(yt))
        let httpMp4 = URL(string: "http://example.com/a.mp4")!
        #expect(!LessonVideoPlaybackPolicy.isNativeAVPlayerHTTPSURL(httpMp4))
    }

    @Test func lessonVideoPlaybackPolicy_extractsYouTubeWatchId() throws {
        let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!
        #expect(LessonVideoPlaybackPolicy.youTubeVideoID(from: url) == "dQw4w9WgXcQ")
    }

    @Test func lessonVideoPlaybackPolicy_nearestUdemyStyleRate() {
        #expect(LessonVideoPlaybackPolicy.nearestPlaybackRate(to: 0.9) == 1.0)
        // Midpoint between 1.0 and 1.25 is 1.125 — values below that snap to 1.0.
        #expect(LessonVideoPlaybackPolicy.nearestPlaybackRate(to: 1.11) == 1.0)
        #expect(LessonVideoPlaybackPolicy.nearestPlaybackRate(to: 1.2) == 1.25)
        #expect(LessonVideoPlaybackPolicy.nearestPlaybackRate(to: 1.8) == 2.0)
    }

    @Test func webVTTParser_findsActiveCue() {
        let doc = InvestorDemoEmbeddedCaptions.englishDocument
        let cues = WebVTTParser.parseCues(from: doc)
        #expect(!cues.isEmpty)
        let atOne = WebVTTParser.activeCue(for: 1.0, in: cues)
        #expect(atOne?.localizedCaseInsensitiveContains("WCS") == true)
    }

    @Test func mockLearning_watchProgressSurfacesOnHydratedLesson() async {
        let courseId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let lessonId = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        await MockLearningStore.shared.resetLearningStateForTests()
        _ = await MockLearningStore.shared.enroll(courseId)
        await MockLearningStore.shared.saveWatchProgress(courseId: courseId, lessonId: lessonId, positionSeconds: 41.5)
        let hydrated = await MockLearningStore.shared.snapshotCourse(courseId)
        let resume = hydrated?.modules.flatMap(\.lessons).first { $0.id == lessonId }?.serverResumePositionSeconds
        #expect(resume == 41.5)
    }

    @Test func mockCatalog_sampleVideoLessonsPreferHLSMaster() {
        let courses = MockCourseCatalog.courses
        let videoURLs = courses.flatMap(\.modules).flatMap(\.lessons).compactMap(\.videoURL).map { URL(string: $0) }.compactMap { $0 }
        #expect(!videoURLs.isEmpty)
        let hlsCount = videoURLs.filter { LessonVideoPlaybackPolicy.isHLSStreamURL($0) }.count
        #expect(hlsCount > 0, "Catalog should include at least one HLS master for native AVPlayer adaptive streaming.")
    }

    @Test func discoverPayload_aggregatesDomainProjections() async throws {
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        defer {
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
        }
        UserDefaults.standard.set(UserRole.learner.rawValue, forKey: "wcs.mockRole")
        let payload = try await NetworkClient.shared.fetchDiscoverPayload()
        #expect(payload.identity.role == .learner)
        #expect(!payload.allPrograms.isEmpty)
        #expect(!payload.featuredPrograms.isEmpty)
        #expect(payload.allPrograms.allSatisfy { !$0.catalog.tags.isEmpty })
        #expect(payload.allPrograms.allSatisfy { !$0.commerce.sku.isEmpty })
    }

    @Test func contentOps_pipelineEndpoints_mockRoundTrip() async throws {
        let planReq = LessonVideoPlanRequest(
            lessonId: "lesson-001",
            moduleId: "module-001",
            moduleTitle: "Module",
            lessonTitle: "Lesson",
            sourceScript: "Explain the water cycle in concise terms.",
            learningObjectives: ["Define evaporation"],
            glossary: ["evaporation"],
            assessmentPrompts: ["Which step forms clouds?"],
            targetAgeBand: "middle-school",
            styleProfileId: nil,
            referenceAssetIds: []
        )
        let planned = try await NetworkClient.shared.planLessonVideo(planReq)
        #expect(planned.lessonId == "lesson-001")
        #expect(!planned.storyboard.scenes.isEmpty)
        #expect(planned.status == "planned")

        let scene = try #require(planned.storyboard.scenes.first)
        let renderReq = LessonVideoSceneRenderRequest(
            lessonId: "lesson-001",
            moduleId: "module-001",
            moduleTitle: "Module",
            scene: scene,
            providerBackendHint: "mock"
        )
        let queued = try await NetworkClient.shared.renderLessonScene(scene.sceneId, request: renderReq)
        #expect(queued.normalizedStatus == .queued)
        let fetched = try await NetworkClient.shared.fetchLessonRenderJob(queued.renderJobId)
        #expect(fetched.normalizedStatus == .completed)

        let composed = try await NetworkClient.shared.composeLessonVideo(
            "lesson-001",
            request: LessonVideoComposeRequest(
                lessonId: "lesson-001",
                moduleId: "module-001",
                includeCaptions: true,
                includeChapterMarkers: true
            )
        )
        #expect(composed.status == "ready_for_composition")

        let output = try await NetworkClient.shared.fetchLessonVideoOutput("lesson-001")
        #expect((output.playbackURL ?? "").hasPrefix("https://"))
        #expect(output.status == "published")
    }

    @Test func lessonManualVideoBackup_mergeExtractAndStrip() {
        let merged = LessonManualVideoBackup.mergeURLLine(
            into: "Instructor notes here.",
            url: "https://cdn.example.com/lesson.mp4"
        )
        #expect(merged.contains("wcs.manualVideoURL:"))
        #expect(LessonManualVideoBackup.extractHTTPSURL(from: merged) == "https://cdn.example.com/lesson.mp4")
        let stripped = LessonManualVideoBackup.stripMachineLines(from: merged)
        #expect(stripped == "Instructor notes here.")
    }

    @Test func lessonManualVideoBackup_externalSourceRoundTrip() {
        let merged = LessonManualVideoBackup.mergeManualVideoMachineLines(
            into: "Notes body.",
            httpsURL: "https://cdn.example.com/mootion-export.mp4",
            externalSource: .mootion
        )
        #expect(merged.contains("wcs.manualVideoURL:"))
        #expect(merged.contains("wcs.externalVideoSource:"))
        #expect(LessonManualVideoBackup.extractHTTPSURL(from: merged) == "https://cdn.example.com/mootion-export.mp4")
        #expect(LessonManualVideoBackup.extractExternalSource(from: merged) == .mootion)
        #expect(LessonManualVideoBackup.stripMachineLines(from: merged) == "Notes body.")
    }

    @Test @MainActor
    func courseDetailViewModel_companionSnippets_matchesLessonScriptLineId() {
        let courseId = UUID(uuidString: "10000000-0000-0000-0000-00000000AA01")!
        let lessonId = UUID(uuidString: "30000000-0000-0000-0000-00000000AA01")!
        let vm = CourseDetailViewModel(courseId: courseId)
        let line = LessonVideoScriptLine(
            id: lessonId,
            courseTitle: "Preview course",
            moduleTitle: "Module A",
            lessonTitle: "Video lesson",
            lessonSubtitle: nil
        )
        let snippets = [
            YouTubeVideoSnippet(videoID: "aqz-KE-bpKQ", title: "Clip A", thumbnailURL: nil),
            YouTubeVideoSnippet(videoID: "eOrNdBpGMv8", title: "Clip B", thumbnailURL: nil),
        ]
        vm.injectCompanionResultsForTests([
            LessonVideoDiscoveryResult(scriptLine: line, snippets: snippets),
        ])
        let got = vm.companionSnippets(forLessonId: lessonId)
        #expect(got.count == 2)
        #expect(got.first?.videoID == "aqz-KE-bpKQ")
    }

}

private struct StubQuestionGenerator: AICourseGenerating {
    func generateDraft(prompt: String, createdBy: String, accessTier: AdminCourseAccessTier) async throws -> AdminCourseDraft {
        makeDraftForTests(
            title: "What is AI?",
            summary: "Question-style generated text.",
            outcomePrefix: "Understand AI basics",
            includeFindings: false
        )
    }
}

private struct StubTitledPublishableGenerator: AICourseGenerating {
    let title: String
    func generateDraft(prompt: String, createdBy: String, accessTier: AdminCourseAccessTier) async throws -> AdminCourseDraft {
        makeDraftForTests(
            title: title,
            summary: "Structured generated curriculum for publish guard tests.",
            outcomePrefix: "Deliver measurable outcomes",
            includeFindings: true
        )
    }
}

private struct StubPublishableGenerator: AICourseGenerating {
    func generateDraft(prompt: String, createdBy: String, accessTier: AdminCourseAccessTier) async throws -> AdminCourseDraft {
        makeDraftForTests(
            title: "AI Ops Mastery",
            summary: "Structured generated curriculum.",
            outcomePrefix: "Operate AI workflows",
            includeFindings: true
        )
    }
}

private func makeDraftForTests(
    title: String,
    summary: String,
    outcomePrefix: String,
    includeFindings: Bool
) -> AdminCourseDraft {
    let lessonVideo = AdminLessonDraft(
        id: UUID(),
        title: "Foundations video",
        kind: .video,
        durationMinutes: 20,
        notes: "Intro"
    )
    let lessonQuiz = AdminLessonDraft(
        id: UUID(),
        title: "Knowledge check",
        kind: .quiz,
        durationMinutes: 10,
        notes: "Quiz"
    )
    let lessonAssignment = AdminLessonDraft(
        id: UUID(),
        title: "Applied assignment",
        kind: .assignment,
        durationMinutes: 30,
        notes: "Assignment"
    )
    let module = AdminModuleDraft(
        id: UUID(),
        title: "Module 1",
        goals: ["Goal 1", "Goal 2"],
        lessons: [lessonVideo, lessonQuiz, lessonAssignment]
    )
    let findings: [AICourseReportFinding] = includeFindings ? [
        AICourseReportFinding(
            id: UUID(),
            title: "Delivery model fit",
            detail: "Weekly cohort is recommended.",
            confidence: 0.88
        )
    ] : []

    return AdminCourseDraft(
        id: UUID(),
        createdAt: Date(),
        updatedAt: Date(),
        createdBy: "admin@wcs",
        title: title,
        summary: summary,
        targetAudience: "Professionals",
        level: "Intermediate",
        durationWeeks: 8,
        outcomes: [
            "\(outcomePrefix) through structured implementation.",
            "Apply concepts to real workflows.",
            "Produce a capstone artifact."
        ],
        modules: [module],
        status: .readyForReview,
        accessTier: .freePublic,
        sourceReferences: ["OpenAlex API"],
        promotionalCopy: ["Launch your next learning milestone."],
        funnelPreview: nil,
        reasoningReport: AIReasoningReport(
            focusQuestion: "How should this course be structured?",
            assumptions: ["Structure improves outcomes."],
            reasoningSteps: [
                AIReasoningStep(
                    id: UUID(),
                    title: "Reasoning",
                    analysis: "Built module structure.",
                    evidence: ["OpenAlex API"]
                )
            ],
            conclusion: "Three-stage progression.",
            confidenceScore: 0.83
        ),
        researchTrace: AIResearchTrace(
            engineName: "WCS Engine",
            retrievalMode: "Hybrid",
            generatedQueries: ["ai operator curriculum"],
            evidenceCards: [
                AIEvidenceCard(
                    id: UUID(),
                    title: "Sample Source",
                    source: "OpenAlex",
                    snippet: "Evidence",
                    relevanceScore: 0.8,
                    freshnessScore: 0.8
                )
            ],
            qualityGate: AIQualityGate(
                passed: true,
                threshold: 0.7,
                score: 0.81,
                rationale: "Good evidence quality."
            ),
            citationMap: [
                AICitationMapping(
                    id: UUID(),
                    claim: "Course should have progressive modules.",
                    sourceTitle: "Sample Source",
                    sourceSystem: "OpenAlex"
                )
            ]
        ),
        cohortSelection: AICohortSelection(
            cohortType: .weeklyCohort,
            recommendedSize: 30,
            rationale: "Balanced facilitation and peer learning."
        ),
        reportFindings: findings
    )
}

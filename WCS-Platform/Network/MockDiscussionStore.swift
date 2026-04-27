//
//  MockDiscussionStore.swift
//  WCS-Platform
//

import Foundation

actor MockDiscussionStore {
    static let shared = MockDiscussionStore()

    private let topics: [DiscussionTopic] = [
        DiscussionTopic(id: "announcements", title: "Announcements", subtitle: "Official WCS updates"),
        DiscussionTopic(id: "study-groups", title: "Study Groups", subtitle: "Peer collaboration and accountability"),
        DiscussionTopic(id: "career", title: "Career Outcomes", subtitle: "Portfolio, jobs, and interview prep"),
        DiscussionTopic(
            id: "wcs:anchor:course:10000000-0000-0000-0000-000000000001:module:20000000-0000-0000-0000-000000000001:lesson:30000000-0000-0000-0000-000000000001",
            title: "Anchored module discussion",
            subtitle: "Tied to a specific lesson for access inheritance tests"
        ),
    ]

    private var posts: [DiscussionPost] = [
        DiscussionPost(
            id: UUID(),
            authorName: "WCS Faculty",
            authorRole: "Instructor",
            topicID: "announcements",
            body: "Live cohort office hours are now open every Thursday. Bring your module questions and capstone blockers.",
            postedAt: Date().addingTimeInterval(-3600),
            likeCount: 42,
            replyCount: 12,
            isPinned: true
        ),
        DiscussionPost(
            id: UUID(),
            authorName: "Ama K.",
            authorRole: "Learner",
            topicID: "study-groups",
            body: "Who wants to form a sprint group for the Applied Practice module this week?",
            postedAt: Date().addingTimeInterval(-7200),
            likeCount: 19,
            replyCount: 8,
            isPinned: false
        ),
        DiscussionPost(
            id: UUID(),
            authorName: "Career Coach",
            authorRole: "Mentor",
            topicID: "career",
            body: "Share one measurable capstone outcome you can put on your CV after this program.",
            postedAt: Date().addingTimeInterval(-9800),
            likeCount: 27,
            replyCount: 15,
            isPinned: false
        )
    ]

    func feed(topicID: String?) -> DiscussionFeedResponse {
        let filtered = posts
            .filter { topicID == nil || $0.topicID == topicID }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
                return $0.postedAt > $1.postedAt
            }
        return DiscussionFeedResponse(topics: topics, posts: filtered)
    }

    func createPost(topicID: String, body: String, authorName: String) -> DiscussionPost {
        let post = DiscussionPost(
            id: UUID(),
            authorName: authorName,
            authorRole: "Learner",
            topicID: topicID,
            body: body,
            postedAt: Date(),
            likeCount: 0,
            replyCount: 0,
            isPinned: false
        )
        posts.insert(post, at: 0)
        return post
    }

    func pipelineStatus() -> PipelineHealthStatus {
        PipelineHealthStatus(
            apiReachable: true,
            middlewareReachable: true,
            realtimeReachable: true,
            databaseReachable: true,
            message: "Mock pipeline is healthy. Live mode checks your backend health endpoints.",
            checkedAt: Date()
        )
    }
}

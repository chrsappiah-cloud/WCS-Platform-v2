//
//  DiscussionViewModel.swift
//  WCS-Platform
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class DiscussionViewModel: ObservableObject {
    @Published var topics: [DiscussionTopic] = []
    @Published var selectedTopicID: String?
    @Published var posts: [DiscussionPost] = []
    @Published var draftPost = ""
    @Published var isLoading = true
    @Published var isPosting = false
    @Published var pipelineStatus: PipelineHealthStatus?
    @Published var errorMessage: String?
    private let communityRepository: CommunityRepository

    init(communityRepository: CommunityRepository = WCSAppContainer.shared.community) {
        self.communityRepository = communityRepository
    }

    var canPost: Bool {
        !draftPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isPosting
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        await loadFeed()
        await loadPipelineStatus()
        isLoading = false
    }

    func selectTopic(_ id: String?) async {
        selectedTopicID = id
        await loadFeed()
    }

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        do {
            let feed = try await communityRepository.fetchDiscussionFeed(topicID: selectedTopicID)
            topics = feed.topics
            posts = feed.posts
        } catch {
            await loadReviewSafeFallback(error: error)
        }
        isLoading = false
    }

    func post(authorName: String) async {
        let message = draftPost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        let topic = selectedTopicID ?? topics.first?.id ?? "announcements"
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            _ = try await communityRepository.createDiscussionPost(topicID: topic, body: message, authorName: authorName)
            draftPost = ""
            await loadFeed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPipelineStatus() async {
        do {
            pipelineStatus = try await communityRepository.fetchPipelineHealthStatus()
        } catch {
            pipelineStatus = await MockDiscussionStore.shared.pipelineStatus()
            Telemetry.event("discussion.pipeline.review_safe_fallback", attributes: [
                "error": String(describing: error)
            ])
        }
    }

    private func loadReviewSafeFallback(error: Error) async {
        let feed = await MockDiscussionStore.shared.feed(topicID: selectedTopicID)
        topics = feed.topics
        posts = feed.posts
        errorMessage = nil
        Telemetry.event("discussion.feed.review_safe_fallback", attributes: [
            "post_count": "\(feed.posts.count)",
            "topic_count": "\(feed.topics.count)",
            "error": String(describing: error)
        ])
    }
}

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
        do {
            async let feed = communityRepository.fetchDiscussionFeed(topicID: selectedTopicID)
            async let pipeline = communityRepository.fetchPipelineHealthStatus()
            let (resolvedFeed, resolvedPipeline) = try await (feed, pipeline)
            topics = resolvedFeed.topics
            posts = resolvedFeed.posts
            pipelineStatus = resolvedPipeline
        } catch {
            errorMessage = error.localizedDescription
        }
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
            errorMessage = error.localizedDescription
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
}

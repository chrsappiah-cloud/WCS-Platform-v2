//
//  YouTubeSearchAPIClient.swift
//  WCS-Platform
//
//  YouTube Data API v3 — https://developers.google.com/youtube/v3/docs/search/list
//  Set `YOUTUBE_DATA_API_KEY` in the scheme environment, or `WCSYouTubeDataAPIKey` in Info.plist
//  (build setting `YOUTUBE_DATA_API_KEY`, same pattern as Perplexity). Environment wins when set.
//

import Foundation
import CryptoKit

struct YouTubeVideoSnippet: Identifiable, Hashable, Sendable {
    var id: String { videoID }
    let videoID: String
    let title: String
    let thumbnailURL: URL?
}

struct YouTubeSearchConfiguration: Sendable {
    var regionCode: String?
    var relevanceLanguage: String?
    var order: String
    var safeSearch: String
    var videoEmbeddable: Bool

    nonisolated static let `default` = YouTubeSearchConfiguration(
        regionCode: nil,
        relevanceLanguage: "en",
        order: "relevance",
        safeSearch: "strict",
        videoEmbeddable: true
    )

    nonisolated static let wcsLearning = YouTubeSearchConfiguration(
        regionCode: nil,
        relevanceLanguage: "en",
        order: "relevance",
        safeSearch: "strict",
        videoEmbeddable: true
    )
}

struct YouTubeSearchPage: Sendable {
    let items: [YouTubeVideoSnippet]
    let nextPageToken: String?
}

enum YouTubeAPIError: Error, LocalizedError {
    case missingAPIKey
    case invalidQuery
    case invalidRequestURL
    case httpStatus(code: Int, message: String?)
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Set YOUTUBE_DATA_API_KEY (scheme env) or WCSYouTubeDataAPIKey in Info.plist via build setting YOUTUBE_DATA_API_KEY."
        case .invalidQuery:
            "Search query is empty or invalid."
        case .invalidRequestURL:
            "Could not build the YouTube Data API request URL."
        case .httpStatus(let code, let message):
            message.map { "YouTube API error (\(code)): \($0)" } ?? "YouTube API error (\(code))."
        case .decodingFailed(let underlying):
            "Could not decode YouTube response: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Response DTOs (explicit Decodable: Swift 6 avoids MainActor-isolated synthesized `init(from:)` in `nonisolated` callers)

private struct YouTubeSearchEnvelope: Sendable {
    struct Item: Sendable {
        struct IDBox: Sendable {
            let kind: String?
            let videoId: String?
        }

        struct Snippet: Sendable {
            struct Thumbnails: Sendable {
                struct Size: Sendable {
                    let url: String?
                }

                let medium: Size?
                let high: Size?
            }

            let title: String?
            let thumbnails: Thumbnails?
        }

        let id: IDBox
        let snippet: Snippet?
    }

    let items: [Item]?
    let nextPageToken: String?
}

extension YouTubeSearchEnvelope: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKey.self)
        nextPageToken = try root.decodeIfPresent(String.self, forKey: .nextPageToken)

        guard root.contains(.items) else {
            items = nil
            return
        }
        var list = try root.nestedUnkeyedContainer(forKey: .items)
        var parsed: [Item] = []
        while !list.isAtEnd {
            let itemRoot = try list.nestedContainer(keyedBy: ItemKey.self)
            let idBox = try Item.IDBox(from: itemRoot.nestedContainer(keyedBy: IDKey.self, forKey: .id))
            let snippet = try Item.Snippet(from: itemRoot, forKey: .snippet)
            parsed.append(Item(id: idBox, snippet: snippet))
        }
        items = parsed
    }

    fileprivate enum RootKey: String, CodingKey {
        case items
        case nextPageToken
    }

    fileprivate enum ItemKey: String, CodingKey {
        case id
        case snippet
    }

    fileprivate enum IDKey: String, CodingKey {
        case kind
        case videoId
    }

    fileprivate enum SnippetKey: String, CodingKey {
        case title
        case thumbnails
    }

    fileprivate enum ThumbKey: String, CodingKey {
        case medium
        case high
    }

    fileprivate enum SizeKey: String, CodingKey {
        case url
    }
}

private extension YouTubeSearchEnvelope.Item.IDBox {
    nonisolated init(from c: KeyedDecodingContainer<YouTubeSearchEnvelope.IDKey>) throws {
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        videoId = try c.decodeIfPresent(String.self, forKey: .videoId)
    }
}

private extension YouTubeSearchEnvelope.Item.Snippet {
    nonisolated init?(from item: KeyedDecodingContainer<YouTubeSearchEnvelope.ItemKey>, forKey key: YouTubeSearchEnvelope.ItemKey) throws {
        guard item.contains(key) else {
            return nil
        }
        let sc = try item.nestedContainer(keyedBy: YouTubeSearchEnvelope.SnippetKey.self, forKey: key)
        title = try sc.decodeIfPresent(String.self, forKey: .title)
        if sc.contains(.thumbnails) {
            let tc = try sc.nestedContainer(keyedBy: YouTubeSearchEnvelope.ThumbKey.self, forKey: .thumbnails)
            let medium = try Self.Thumbnails.Size(from: tc, forKey: .medium)
            let high = try Self.Thumbnails.Size(from: tc, forKey: .high)
            thumbnails = Self.Thumbnails(medium: medium, high: high)
        } else {
            thumbnails = nil
        }
    }
}

private extension YouTubeSearchEnvelope.Item.Snippet.Thumbnails.Size {
    nonisolated init?(from thumbs: KeyedDecodingContainer<YouTubeSearchEnvelope.ThumbKey>, forKey key: YouTubeSearchEnvelope.ThumbKey) throws {
        guard thumbs.contains(key) else { return nil }
        let zc = try thumbs.nestedContainer(keyedBy: YouTubeSearchEnvelope.SizeKey.self, forKey: key)
        url = try zc.decodeIfPresent(String.self, forKey: .url)
    }
}

private struct YouTubeAPIErrorEnvelope: Sendable {
    struct Box: Sendable {
        let code: Int?
        let message: String?
        struct Err: Sendable {
            let message: String?
        }

        let errors: [Err]?
    }

    let error: Box?
}

extension YouTubeAPIErrorEnvelope: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKey.self)
        if root.contains(.error) {
            let ec = try root.nestedContainer(keyedBy: ErrorBoxKey.self, forKey: .error)
            let code = try ec.decodeIfPresent(Int.self, forKey: .code)
            let message = try ec.decodeIfPresent(String.self, forKey: .message)
            var errs: [Box.Err] = []
            if var arr = try? ec.nestedUnkeyedContainer(forKey: .errors) {
                while !arr.isAtEnd {
                    let errC = try arr.nestedContainer(keyedBy: ErrKey.self)
                    let m = try errC.decodeIfPresent(String.self, forKey: .message)
                    errs.append(Box.Err(message: m))
                }
            }
            error = Box(code: code, message: message, errors: errs.isEmpty ? nil : errs)
        } else {
            error = nil
        }
    }

    private enum RootKey: String, CodingKey {
        case error
    }

    private enum ErrorBoxKey: String, CodingKey {
        case code
        case message
        case errors
    }

    private enum ErrKey: String, CodingKey {
        case message
    }
}

enum YouTubeSearchAPIClient {
    private static let service = "youtube"
    private static let cacheMaxAge: TimeInterval = 60 * 30
    nonisolated private static let requestTimeout: TimeInterval = 20
    nonisolated private static let maxQueryLength = 180
    nonisolated private static let maxPageTokenLength = 256

    nonisolated static func resolveAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["YOUTUBE_DATA_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !env.isEmpty {
            return env
        }
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "WCSYouTubeDataAPIKey") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("$(") { return nil }
        return trimmed
    }

    nonisolated static func searchVideos(
        query: String,
        configuration: YouTubeSearchConfiguration? = nil,
        pageToken: String? = nil,
        maxResults: Int = 8,
        session: URLSession? = nil
    ) async throws -> YouTubeSearchPage {
        let normalizedQuery = try validatedQuery(query)
        let safePageToken = sanitizedPageToken(pageToken)
        let configuration = configuration ?? .wcsLearning
        let session = session ?? makeDefaultSession()
        guard let apiKey = resolveAPIKey() else {
            throw YouTubeAPIError.missingAPIKey
        }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "\(max(1, min(maxResults, 50)))"),
            URLQueryItem(name: "q", value: normalizedQuery),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "order", value: configuration.order),
            URLQueryItem(name: "safeSearch", value: configuration.safeSearch),
        ]
        if configuration.videoEmbeddable {
            items.append(URLQueryItem(name: "videoEmbeddable", value: "true"))
        }
        if let region = configuration.regionCode, !region.isEmpty {
            items.append(URLQueryItem(name: "regionCode", value: region.uppercased()))
        }
        if let lang = configuration.relevanceLanguage, !lang.isEmpty {
            items.append(URLQueryItem(name: "relevanceLanguage", value: lang))
        }
        if let safePageToken, !safePageToken.isEmpty {
            items.append(URLQueryItem(name: "pageToken", value: safePageToken))
        }
        components.queryItems = items

        guard let url = components.url else {
            throw YouTubeAPIError.invalidRequestURL
        }

        let request: URLRequest = {
            var r = URLRequest(url: url)
            r.httpMethod = "GET"
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            return r
        }()

        let cacheKey = hashedCacheKey(
            query: normalizedQuery,
            maxResults: maxResults,
            configuration: configuration,
            pageToken: safePageToken
        )
        do {
            let data = try await ExternalServiceResilience.withRetry(service: service) {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw YouTubeAPIError.httpStatus(code: -1, message: nil)
                }
                guard (200 ..< 300).contains(http.statusCode) else {
                    let message = Self.decodeYouTubeErrorMessage(from: data) ?? String(data: data, encoding: .utf8)
                    throw YouTubeAPIError.httpStatus(code: http.statusCode, message: message)
                }
                return data
            }
            await ExternalResponseCache.shared.set(service: service, key: cacheKey, payload: data)
            return try decodePage(from: data)
        } catch {
            guard let stale = await ExternalResponseCache.shared.get(service: service, key: cacheKey, maxAge: cacheMaxAge) else {
                throw error
            }
            return (try? decodePage(from: stale)) ?? YouTubeSearchPage(items: [], nextPageToken: nil)
        }
    }

    nonisolated static func decodePage(from data: Data) throws -> YouTubeSearchPage {
        let decoded: YouTubeSearchEnvelope
        do {
            decoded = try JSONDecoder().decode(YouTubeSearchEnvelope.self, from: data)
        } catch {
            throw YouTubeAPIError.decodingFailed(underlying: error)
        }

        let snippets: [YouTubeVideoSnippet] = (decoded.items ?? []).compactMap { item in
            guard let videoID = item.id.videoId else { return nil }
            let title = item.snippet?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Video"
            let urlString = item.snippet?.thumbnails?.high?.url
                ?? item.snippet?.thumbnails?.medium?.url
            let thumb = urlString.flatMap(URL.init(string:))
            return YouTubeVideoSnippet(videoID: videoID, title: title, thumbnailURL: thumb)
        }
        return YouTubeSearchPage(items: snippets, nextPageToken: decoded.nextPageToken)
    }

    nonisolated private static func decodeYouTubeErrorMessage(from data: Data) -> String? {
        guard let env = try? JSONDecoder().decode(YouTubeAPIErrorEnvelope.self, from: data) else {
            return nil
        }
        if let first = env.error?.errors?.first?.message, !first.isEmpty {
            return first
        }
        return env.error?.message
    }

    nonisolated private static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    nonisolated private static func validatedQuery(_ query: String) throws -> String {
        let collapsed = query
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else {
            throw YouTubeAPIError.invalidQuery
        }

        let cleaned = String(collapsed.prefix(maxQueryLength))
        guard cleaned.rangeOfCharacter(from: .letters) != nil else {
            throw YouTubeAPIError.invalidQuery
        }
        return cleaned
    }

    nonisolated private static func sanitizedPageToken(_ token: String?) -> String? {
        guard let token else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard trimmed.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return String(trimmed.prefix(maxPageTokenLength))
    }

    nonisolated private static func hashedCacheKey(
        query: String,
        maxResults: Int,
        configuration: YouTubeSearchConfiguration,
        pageToken: String?
    ) -> String {
        let seed = [
            query,
            String(maxResults),
            configuration.order,
            configuration.safeSearch,
            configuration.relevanceLanguage ?? "",
            configuration.regionCode ?? "",
            configuration.videoEmbeddable ? "1" : "0",
            pageToken ?? ""
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(seed.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

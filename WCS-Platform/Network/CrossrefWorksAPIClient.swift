//
//  CrossrefWorksAPIClient.swift
//  WCS-Platform
//
//  Crossref REST API — open scholarly metadata (no API key for polite use).
//  https://github.com/CrossRef/rest-api-doc
//

import Foundation

struct CrossrefWorkSummary: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let doi: String?
    let resourceURL: URL?
}

private struct CrossrefWorksEnvelope: Decodable {
    struct Message: Decodable {
        struct Item: Decodable {
            let title: [String]?
            let DOI: String?
            let URL: String?
        }

        let items: [Item]?
    }

    let message: Message?
}

enum CrossrefWorksAPIClient {
    private static let service = "crossref"
    private static let cacheMaxAge: TimeInterval = 60 * 60 * 6

    static func searchWorks(
        query: String,
        rows: Int = 5,
        session: URLSession = .shared
    ) async throws -> [CrossrefWorkSummary] {
        var components = URLComponents(string: "https://api.crossref.org/works")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "rows", value: "\(max(1, min(rows, 20)))"),
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let request: URLRequest = {
            var r = URLRequest(url: url)
            r.httpMethod = "GET"
            r.timeoutInterval = 14
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            r.setValue(
                "WCS-Platform/1.0 (mailto:support@wcs.education; https://github.com/CrossRef/rest-api-doc)",
                forHTTPHeaderField: "User-Agent"
            )
            return r
        }()

        do {
            let data = try await ExternalServiceResilience.withRetry(service: service) {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200 ..< 300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            await ExternalResponseCache.shared.set(service: service, key: "\(query)|\(rows)", payload: data)
            return try decodeWorks(from: data)
        } catch {
            guard let stale = await ExternalResponseCache.shared.get(
                service: service,
                key: "\(query)|\(rows)",
                maxAge: cacheMaxAge
            ) else {
                throw error
            }
            return (try? decodeWorks(from: stale)) ?? []
        }
    }

    static func decodeWorks(from data: Data) throws -> [CrossrefWorkSummary] {
        let decoded = try JSONDecoder().decode(CrossrefWorksEnvelope.self, from: data)
        let items = decoded.message?.items ?? []

        return items.enumerated().compactMap { idx, item in
            let title = (item.title?.first?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { text in
                text.isEmpty ? nil : text
            } ?? "Untitled work"
            let doi = item.DOI?.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = doi.flatMap { $0.isEmpty ? nil : $0 } ?? "crossref-\(idx)-\(title.hashValue)"
            let resource = item.URL.flatMap(URL.init(string:))
                ?? doi.flatMap { URL(string: "https://doi.org/\($0)") }
            return CrossrefWorkSummary(id: id, title: title, doi: doi, resourceURL: resource)
        }
    }
}

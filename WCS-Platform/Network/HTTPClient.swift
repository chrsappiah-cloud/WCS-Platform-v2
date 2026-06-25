//
//  HTTPClient.swift
//  WCS-Platform
//

import Foundation

struct HTTPRequest: Sendable, Equatable {
    var url: URL
    var method: String
    var headers: [String: String]
    var body: Data?

    init(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

struct HTTPResponse: Sendable, Equatable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data?

    init(statusCode: Int, headers: [String: String] = [:], body: Data? = nil) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        request.headers.forEach { header, value in
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, entry in
            guard let key = entry.key as? String else { return }
            result[key] = String(describing: entry.value)
        }

        return HTTPResponse(statusCode: httpResponse.statusCode, headers: headers, body: data)
    }
}

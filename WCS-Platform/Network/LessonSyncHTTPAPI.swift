//
//  LessonSyncHTTPAPI.swift
//  WCS-Platform
//

import Foundation

final class LessonSyncHTTPAPI: LessonSyncAPI {
    private let client: HTTPClient
    private let baseURL: URL
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    init(
        baseURL: URL,
        client: HTTPClient,
        jsonDecoder: JSONDecoder = JSONDecoder(),
        jsonEncoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.client = client
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        self.jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func fetchServerVersion(lessonID: String) async throws -> Int {
        let url = baseURL
            .appendingPathComponent("lessons")
            .appendingPathComponent(lessonID)
            .appendingPathComponent("sync-version")
        let request = HTTPRequest(url: url)

        do {
            let response = try await client.execute(request)
            try mapCommonErrors(statusCode: response.statusCode, body: response.body)
            let body = try requireBody(response.body)
            let dto = try jsonDecoder.decode(LessonVersionDTO.self, from: body)
            return dto.version
        } catch let error as LessonSyncError {
            throw error
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw LessonSyncError.transport(error.localizedDescription)
        }
    }

    func push(_ progress: LessonSyncProgress) async throws -> LessonSyncReceipt {
        let url = baseURL
            .appendingPathComponent("lessons")
            .appendingPathComponent(progress.lessonID)
            .appendingPathComponent("progress")
        let dto = LessonProgressDTO(
            userID: progress.userID,
            percentComplete: progress.percentComplete,
            updatedAt: Self.iso8601String(from: progress.updatedAt)
        )
        let request = HTTPRequest(
            url: url,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: try jsonEncoder.encode(dto)
        )

        do {
            let response = try await client.execute(request)
            try mapCommonErrors(statusCode: response.statusCode, body: response.body)
            let body = try requireBody(response.body)
            let dto = try jsonDecoder.decode(SyncReceiptDTO.self, from: body)
            guard let syncID = UUID(uuidString: dto.syncId) else {
                throw LessonSyncError.transport("Invalid sync_id")
            }
            return LessonSyncReceipt(syncID: syncID, serverVersion: dto.serverVersion)
        } catch let error as LessonSyncError {
            throw error
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw LessonSyncError.transport(error.localizedDescription)
        }
    }

    private static func iso8601String(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func requireBody(_ body: Data?) throws -> Data {
        guard let body else {
            throw LessonSyncError.transport("Empty response body")
        }
        return body
    }

    private func mapCommonErrors(statusCode: Int, body: Data?) throws {
        guard !(200..<300).contains(statusCode) else { return }

        switch statusCode {
        case 409:
            throw LessonSyncError.conflict
        case 412:
            throw LessonSyncError.transport("Stale client")
        default:
            let snippet = body
                .flatMap { String(data: $0, encoding: .utf8) }
                .map { String($0.prefix(200)) } ?? ""
            throw LessonSyncError.transport("HTTP \(statusCode): \(snippet)")
        }
    }

    private func mapURLError(_ error: URLError) -> LessonSyncError {
        switch error.code {
        case .notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
            return .offline
        default:
            return .transport(error.localizedDescription)
        }
    }
}

private struct LessonVersionDTO: Decodable {
    let version: Int
}

private struct SyncReceiptDTO: Decodable {
    let syncId: String
    let serverVersion: Int
}

private struct LessonProgressDTO: Encodable {
    let userID: String
    let percentComplete: Int
    let updatedAt: String
}

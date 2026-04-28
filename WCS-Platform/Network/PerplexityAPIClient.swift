//
//  PerplexityAPIClient.swift
//  WCS-Platform
//
//  Perplexity Sonar (chat completions) — https://docs.perplexity.ai/
//  Configure `WCSPerplexityAPIKey` in Info.plist (build setting `WCS_PERPLEXITY_API_KEY`) or
//  set `PERPLEXITY_API_KEY` in the scheme environment (takes precedence).
//

import Foundation

enum PerplexityAPIClient {
    private static let chatCompletionsURL = URL(string: "https://api.perplexity.ai/chat/completions")!
    private static let requestTimeout: TimeInterval = 45

    nonisolated static func resolveAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["PERPLEXITY_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !env.isEmpty {
            return env
        }
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "WCSPerplexityAPIKey") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("$(") { return nil }
        return trimmed
    }

    /// Short web-grounded lines for admin mock course research (best-effort; empty on failure).
    nonisolated static func fetchResearchLines(topic: String, maxLines: Int = 5) async -> [String] {
        guard let apiKey = resolveAPIKey() else { return [] }
        let cleaned = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        var request = URLRequest(url: chatCompletionsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let prompt = """
        List up to \(maxLines) concise related reference titles (papers, books, or major resources) for: \(cleaned).
        One title per line. No numbering or bullets. No commentary.
        """
        let body: [String: Any] = [
            "model": "sonar",
            "max_tokens": 400,
            "messages": [
                ["role": "user", "content": prompt],
            ],
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return [] }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                return []
            }
            let decoded = try JSONDecoder().decode(ChatCompletionEnvelope.self, from: data)
            let text = decoded.choices?.first?.message?.content ?? ""
            return Self.parseTitleLines(text, max: maxLines)
        } catch {
            return []
        }
    }

    nonisolated private static func parseTitleLines(_ text: String, max: Int) -> [String] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { line in
                line.replacingOccurrences(
                    of: #"^[\d\.\)\-\u2022\*]+\s*"#,
                    with: "",
                    options: .regularExpression
                )
            }
            .filter { !$0.isEmpty && $0.count > 3 }
        return Array(lines.prefix(max))
    }

    private struct ChatCompletionEnvelope: Decodable, Sendable {
        struct Choice: Decodable, Sendable {
            struct Message: Decodable, Sendable {
                let content: String?
            }

            let message: Message?
        }

        let choices: [Choice]?
    }
}

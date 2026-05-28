//
//  JSONFixtureLoader.swift
//  WCS-Platform
//

import Foundation

enum JSONFixtureLoader {
    static func loadString(named fileName: String, in bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw NSError(domain: "WCSFixtureLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing fixture \(fileName).json"])
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func decode<T: Decodable>(
        _ type: T.Type,
        named fileName: String,
        in bundle: Bundle = .main,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw NSError(domain: "WCSFixtureLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing fixture \(fileName).json"])
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }
}

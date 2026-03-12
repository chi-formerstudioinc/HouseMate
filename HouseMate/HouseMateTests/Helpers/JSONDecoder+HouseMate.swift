// HouseMateTests/Helpers/JSONDecoder+HouseMate.swift
import Foundation

extension JSONDecoder {
    static var houseMate: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = ISO8601DateFormatter().date(from: s) { return date }
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone(identifier: "UTC")
            if let date = df.date(from: s) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Cannot decode date from '\(s)'"))
        }
        return decoder
    }
}

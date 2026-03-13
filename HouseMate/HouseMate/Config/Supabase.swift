// HouseMate/Config/Supabase.swift
import Foundation
import Supabase

let supabase: SupabaseClient = {
    guard let url = URL(string: Secrets.supabaseURL),
          !Secrets.supabaseURL.contains("YOUR_PROJECT") else {
        preconditionFailure("Configure Secrets.swift: set supabaseURL to your Supabase project URL")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
}()

/// Shared decoder that handles both ISO8601 timestamps (TIMESTAMPTZ) and date-only strings (DATE).
/// Note: the supabase-swift SDK uses its own internal decoder for `.execute().value` responses.
/// Use HouseMateDecoder directly when decoding raw Data (e.g. in tests or custom fetch paths).
enum HouseMateDecoder {
    private static let iso8601Formatter = ISO8601DateFormatter()
    private static let dateOnlyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        return df
    }()

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = iso8601Formatter.date(from: s) { return date }
            if let date = dateOnlyFormatter.date(from: s) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Cannot decode date from '\(s)'"))
        }
        return try decoder.decode(type, from: data)
    }
}

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

enum HouseMateDecoder {
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
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
        return try decoder.decode(type, from: data)
    }
}

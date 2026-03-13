// HouseMate/Models/Member.swift
import Foundation

struct Member: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    let userId: UUID
    let displayName: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case userId = "user_id"
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

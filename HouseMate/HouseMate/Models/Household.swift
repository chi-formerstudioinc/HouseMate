// HouseMate/Models/Household.swift
import Foundation

struct Household: Codable, Identifiable {
    let id: UUID
    let name: String
    let createdBy: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct HouseholdInvite: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    let inviteCode: String
    let isActive: Bool
    let createdBy: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case inviteCode = "invite_code"
        case isActive = "is_active"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

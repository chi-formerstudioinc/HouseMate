// HouseMate/Services/HouseholdService.swift
import Supabase
import Foundation

@MainActor
final class HouseholdService {

    func createHousehold(name: String, displayName: String, userId: UUID) async throws -> (Household, Member) {
        // Insert household
        let household: Household = try await supabase
            .from("households")
            .insert(HouseholdInsert(name: name, created_by: userId))
            .select()
            .single()
            .execute()
            .value

        // Insert member
        let member: Member = try await supabase
            .from("members")
            .insert(MemberInsert(household_id: household.id, user_id: userId, display_name: displayName))
            .select()
            .single()
            .execute()
            .value

        // Generate invite code
        try await generateNewInviteCode(householdId: household.id, userId: userId)

        return (household, member)
    }

    func joinHousehold(inviteCode: String, displayName: String, userId: UUID) async throws -> (Household, Member) {
        // Look up invite
        let invite: HouseholdInvite = try await supabase
            .from("household_invites")
            .select()
            .eq("invite_code", value: inviteCode.uppercased())
            .eq("is_active", value: true)
            .single()
            .execute()
            .value

        // Check member count
        let memberCount: Int = try await supabase
            .from("members")
            .select("id", head: true, count: .exact)
            .eq("household_id", value: invite.householdId.uuidString)
            .execute()
            .count ?? 0
        guard memberCount < 6 else { throw HouseholdError.householdFull }

        // Insert member
        let member: Member = try await supabase
            .from("members")
            .insert(MemberInsert(household_id: invite.householdId, user_id: userId, display_name: displayName))
            .select()
            .single()
            .execute()
            .value

        // Fetch household
        let household: Household = try await supabase
            .from("households")
            .select()
            .eq("id", value: invite.householdId.uuidString)
            .single()
            .execute()
            .value

        return (household, member)
    }

    func fetchHousehold(id: UUID) async throws -> Household {
        try await supabase
            .from("households")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func updateHouseholdName(_ name: String, householdId: UUID) async throws {
        try await supabase
            .from("households")
            .update(["name": name])
            .eq("id", value: householdId.uuidString)
            .execute()
    }

    func activeInviteCode(householdId: UUID) async throws -> String? {
        let invites: [HouseholdInvite] = try await supabase
            .from("household_invites")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .eq("is_active", value: true)
            .execute()
            .value
        return invites.first?.inviteCode
    }

    func regenerateInviteCode(householdId: UUID, userId: UUID) async throws -> String {
        // Deactivate existing codes
        try await supabase
            .from("household_invites")
            .update(InviteDeactivate(is_active: false))
            .eq("household_id", value: householdId.uuidString)
            .execute()
        return try await generateNewInviteCode(householdId: householdId, userId: userId)
    }

    @discardableResult
    private func generateNewInviteCode(householdId: UUID, userId: UUID) async throws -> String {
        let code = HouseholdService.generateInviteCode()
        try await supabase
            .from("household_invites")
            .insert(InviteInsert(household_id: householdId, invite_code: code, created_by: userId))
            .execute()
        return code
    }

    nonisolated static func generateInviteCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }
}

enum HouseholdError: LocalizedError {
    case householdFull
    case invalidCode
    var errorDescription: String? {
        switch self {
        case .householdFull: return "This household is full (max 6 members)."
        case .invalidCode: return "That code wasn't found. Check the code and try again."
        }
    }
}

// MARK: - Insert helpers (private to this file)
private struct HouseholdInsert: Encodable {
    let name: String
    let created_by: UUID
}

private struct MemberInsert: Encodable {
    let household_id: UUID
    let user_id: UUID
    let display_name: String
}

private struct InviteInsert: Encodable {
    let household_id: UUID
    let invite_code: String
    let created_by: UUID
}

private struct InviteDeactivate: Encodable {
    let is_active: Bool
}

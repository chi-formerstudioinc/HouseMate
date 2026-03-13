// HouseMate/Services/MemberService.swift
import Supabase
import Foundation

@MainActor
final class MemberService {
    func fetchMembers(householdId: UUID) async throws -> [Member] {
        try await supabase
            .from("members")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func fetchMember(userId: UUID) async throws -> Member? {
        let members: [Member] = try await supabase
            .from("members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return members.first
    }

    func updateDisplayName(_ name: String, memberId: UUID) async throws {
        try await supabase
            .from("members")
            .update(["display_name": name])
            .eq("id", value: memberId.uuidString)
            .execute()
    }
}

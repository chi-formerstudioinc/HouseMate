// HouseMate/State/AppState.swift
import Observation
import Foundation
import Supabase

@Observable
@MainActor
final class AppState {
    var household: Household?
    var currentMember: Member?
    var members: [Member] = []

    private let authService = AuthService()

    var isAuthenticated: Bool { authService.currentUser != nil }
    var hasHousehold: Bool { household != nil }
    var currentUserId: UUID? { authService.currentUser?.id }

    func loadSession() async {
        _ = try? await authService.restoreSession()
        guard isAuthenticated, let userId = currentUserId else { return }
        let memberService = MemberService()
        guard let member = try? await memberService.fetchMember(userId: userId) else { return }
        currentMember = member
        let householdService = HouseholdService()
        household = try? await householdService.fetchHousehold(id: member.householdId)
        members = (try? await memberService.fetchMembers(householdId: member.householdId)) ?? []
    }

    func signOut() async throws {
        try await authService.signOut()
        household = nil
        currentMember = nil
        members = []
    }

    func memberName(for memberId: UUID?) -> String {
        guard let memberId else { return "Unknown" }
        return members.first { $0.id == memberId }?.displayName ?? "Unknown"
    }
}

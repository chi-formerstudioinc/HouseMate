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
    var isAuthenticated = false
    var currentUserId: UUID?

    var hasHousehold: Bool { household != nil }

    // Call once on app launch — listens to Supabase auth events for the lifetime of the app.
    nonisolated func startListeningToAuth() {
        Task { @MainActor in
            for await (event, session) in supabase.auth.authStateChanges {
                isAuthenticated = session != nil
                currentUserId = session?.user.id

                switch event {
                case .initialSession, .signedIn, .tokenRefreshed:
                    if let userId = session?.user.id {
                        await loadHouseholdData(userId: userId)
                    }
                case .signedOut:
                    household = nil
                    currentMember = nil
                    members = []
                default:
                    break
                }
            }
        }
    }

    private func loadHouseholdData(userId: UUID) async {
        let memberService = MemberService()
        guard let member = try? await memberService.fetchMember(userId: userId) else { return }
        currentMember = member
        let householdService = HouseholdService()
        household = try? await householdService.fetchHousehold(id: member.householdId)
        members = (try? await memberService.fetchMembers(householdId: member.householdId)) ?? []
    }

    func signOut() async throws {
        defer {
            household = nil
            currentMember = nil
            members = []
            isAuthenticated = false
            currentUserId = nil
        }
        try await supabase.auth.signOut()
    }

    func memberName(for memberId: UUID?) -> String {
        guard let memberId else { return "Unknown" }
        return members.first { $0.id == memberId }?.displayName ?? "Unknown"
    }
}

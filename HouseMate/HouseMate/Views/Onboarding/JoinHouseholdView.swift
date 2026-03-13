// HouseMate/Views/Onboarding/JoinHouseholdView.swift
import SwiftUI

struct JoinHouseholdView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let householdService = HouseholdService()
    private let memberService = MemberService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite Code") {
                    TextField("Enter 8-character code", text: $inviteCode)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }
                Section("Your Name") {
                    TextField("How should we call you?", text: $displayName)
                }
                if let error = errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Join Household")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") { Task { await join() } }
                        .disabled(isLoading || inviteCode.count != 8 || displayName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .disabled(isLoading)
        }
    }

    private func join() async {
        guard let userId = appState.currentUserId else { return }
        isLoading = true
        errorMessage = nil
        do {
            let (household, member) = try await householdService.joinHousehold(
                inviteCode: inviteCode, displayName: displayName, userId: userId)
            let allMembers = try await memberService.fetchMembers(householdId: household.id)
            appState.household = household
            appState.currentMember = member
            appState.members = allMembers
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

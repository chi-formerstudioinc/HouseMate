// HouseMate/Views/Onboarding/CreateHouseholdView.swift
import SwiftUI

struct CreateHouseholdView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var householdName = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let householdService = HouseholdService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Household") {
                    TextField("e.g. The Smith Household", text: $householdName)
                }
                Section("Your Name") {
                    TextField("How should we call you?", text: $displayName)
                }
                if let error = errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Create Household")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(isLoading || householdName.isEmpty || displayName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .disabled(isLoading)
        }
    }

    private func create() async {
        guard let userId = appState.currentUserId else { return }
        defer { isLoading = false }
        isLoading = true
        errorMessage = nil
        do {
            let (household, member) = try await householdService.createHousehold(
                name: householdName, displayName: displayName, userId: userId)
            appState.household = household
            appState.currentMember = member
            appState.members = [member]
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

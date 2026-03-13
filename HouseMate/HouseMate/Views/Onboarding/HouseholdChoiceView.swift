// HouseMate/Views/Onboarding/HouseholdChoiceView.swift
import SwiftUI

struct HouseholdChoiceView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Welcome to HouseMate")
                    .font(.largeTitle).bold()
                Text("Set up your household to get started.")
                    .foregroundStyle(.secondary)
                Button("Create a Household") { showCreate = true }
                    .buttonStyle(.borderedProminent)
                Button("Join a Household") { showJoin = true }
                    .buttonStyle(.bordered)
            }
            .padding()
            .sheet(isPresented: $showCreate) { CreateHouseholdView().environment(appState) }
            .sheet(isPresented: $showJoin) { JoinHouseholdView().environment(appState) }
        }
    }
}

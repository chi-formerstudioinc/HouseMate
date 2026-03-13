// HouseMate/App/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if !appState.isAuthenticated {
            AuthView()
        } else if !appState.hasHousehold {
            HouseholdChoiceView()
        } else {
            MainTabView()
        }
    }
}

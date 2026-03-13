// HouseMate/App/HouseMateApp.swift
import SwiftUI

@main
struct HouseMateApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .task { await appState.loadSession() }
        }
    }
}

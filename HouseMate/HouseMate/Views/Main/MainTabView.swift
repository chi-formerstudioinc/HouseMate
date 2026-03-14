// HouseMate/Views/Main/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Text("Home")
                .tabItem { Label("Home", systemImage: "house") }
            Text("Tasks")
                .tabItem { Label("Tasks", systemImage: "checklist") }
            Text("Bins")
                .tabItem { Label("Bins", systemImage: "trash") }
            MaintenanceListView()
                .tabItem { Label("Home Care", systemImage: "house.and.flag") }
        }
    }
}

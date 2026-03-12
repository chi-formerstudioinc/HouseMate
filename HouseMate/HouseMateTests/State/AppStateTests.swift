// HouseMateTests/State/AppStateTests.swift
import XCTest
@testable import HouseMate

// Note: These tests require Secrets.swift to be configured with a valid Supabase URL and anon key.
@MainActor
final class AppStateTests: XCTestCase {
    func test_appState_initiallyUnauthenticated() async {
        let state = AppState()
        XCTAssertFalse(state.isAuthenticated)
        XCTAssertNil(state.currentMember)
        XCTAssertNil(state.household)
        XCTAssertTrue(state.members.isEmpty)
    }

    func test_appState_hasHousehold_whenHouseholdSet() async {
        let state = AppState()
        XCTAssertFalse(state.hasHousehold)
        state.household = Household(id: UUID(), name: "Test", createdBy: UUID(), createdAt: Date())
        XCTAssertTrue(state.hasHousehold)
    }
}

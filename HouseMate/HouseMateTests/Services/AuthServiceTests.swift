// HouseMateTests/Services/AuthServiceTests.swift
import XCTest
@testable import HouseMate

// Note: These tests require Secrets.swift to be configured with a valid Supabase URL and anon key.
// Copy Secrets.swift.example to Secrets.swift and fill in your project credentials before running.
@MainActor
final class AuthServiceTests: XCTestCase {
    func test_authService_exists() async {
        let service = AuthService()
        XCTAssertNotNil(service)
    }

    func test_currentUser_isNilWhenNotSignedIn() async {
        let service = AuthService()
        // In test environment (no active session), currentUser should be nil
        XCTAssertNil(service.currentUser)
    }
}

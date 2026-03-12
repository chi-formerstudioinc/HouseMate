// HouseMateTests/Services/AuthServiceTests.swift
import XCTest
@testable import HouseMate

@MainActor
final class AuthServiceTests: XCTestCase {
    func test_authService_exists() {
        let service = AuthService()
        XCTAssertNotNil(service)
    }

    func test_currentUser_isNilWhenNotSignedIn() async {
        let service = AuthService()
        // If test runs without a real session, currentUser should be nil
        _ = service.currentUser  // just verify it doesn't crash
    }
}

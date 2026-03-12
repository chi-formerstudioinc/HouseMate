// HouseMateTests/Services/AuthServiceTests.swift
import XCTest
@testable import HouseMate

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

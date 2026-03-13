// HouseMateTests/Services/HouseholdServiceTests.swift
import XCTest
@testable import HouseMate

final class HouseholdServiceTests: XCTestCase {
    func test_generateInviteCode_isEightCharacters() {
        let code = HouseholdService.generateInviteCode()
        XCTAssertEqual(code.count, 8)
    }

    func test_generateInviteCode_isAlphanumeric() {
        let code = HouseholdService.generateInviteCode()
        let allowed = CharacterSet.alphanumerics
        XCTAssertTrue(code.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    func test_generateInviteCode_isUppercase() {
        let code = HouseholdService.generateInviteCode()
        XCTAssertEqual(code, code.uppercased())
    }
}

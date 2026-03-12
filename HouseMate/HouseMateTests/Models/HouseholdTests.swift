// HouseMateTests/Models/HouseholdTests.swift
import XCTest
@testable import HouseMate

final class HouseholdTests: XCTestCase {
    func test_household_decodesFromJSON() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Test House",
          "created_by": "00000000-0000-0000-0000-000000000002",
          "created_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let household = try decoder.decode(Household.self, from: json)
        XCTAssertEqual(household.name, "Test House")
    }

    func test_member_decodesFromJSON() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "household_id": "00000000-0000-0000-0000-000000000002",
          "user_id": "00000000-0000-0000-0000-000000000003",
          "display_name": "Alice",
          "created_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let member = try decoder.decode(Member.self, from: json)
        XCTAssertEqual(member.displayName, "Alice")
    }
}

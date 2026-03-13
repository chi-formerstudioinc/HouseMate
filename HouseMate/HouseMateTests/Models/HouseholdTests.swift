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
        let household = try HouseMateDecoder.decode(Household.self, from: json)
        XCTAssertEqual(household.name, "Test House")
        XCTAssertEqual(household.id, UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        XCTAssertEqual(household.createdBy, UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        XCTAssertNotNil(household.createdAt)
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
        let member = try HouseMateDecoder.decode(Member.self, from: json)
        XCTAssertEqual(member.displayName, "Alice")
        XCTAssertEqual(member.id, UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        XCTAssertEqual(member.householdId, UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        XCTAssertEqual(member.userId, UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
        XCTAssertNotNil(member.createdAt)
    }

    func test_householdInvite_decodesFromJSON() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "household_id": "00000000-0000-0000-0000-000000000002",
          "invite_code": "ABC12345",
          "is_active": true,
          "created_by": "00000000-0000-0000-0000-000000000003",
          "created_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let invite = try HouseMateDecoder.decode(HouseholdInvite.self, from: json)
        XCTAssertEqual(invite.inviteCode, "ABC12345")
        XCTAssertTrue(invite.isActive)
        XCTAssertEqual(invite.householdId, UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        XCTAssertEqual(invite.createdBy, UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
        XCTAssertNotNil(invite.createdAt)
    }
}

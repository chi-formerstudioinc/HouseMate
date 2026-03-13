// HouseMateTests/Services/RealtimeServiceTests.swift
import XCTest
@testable import HouseMate

// Note: These tests require Secrets.swift to be configured with a valid Supabase URL and anon key.
@MainActor
final class RealtimeServiceTests: XCTestCase {
    func test_realtimeService_canBeInstantiated() async {
        let service = RealtimeService()
        XCTAssertNotNil(service)
    }

    func test_notificationNames_areCorrect() async {
        XCTAssertEqual(RealtimeService.tasksChangedNotification.rawValue, "RealtimeTasksChanged")
        XCTAssertEqual(RealtimeService.binScheduleChangedNotification.rawValue, "RealtimeBinScheduleChanged")
        XCTAssertEqual(RealtimeService.maintenanceChangedNotification.rawValue, "RealtimeMaintenanceChanged")
        XCTAssertEqual(RealtimeService.membersChangedNotification.rawValue, "RealtimeMembersChanged")
    }
}

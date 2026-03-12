// HouseMateTests/Models/MaintenanceItemTests.swift
import XCTest
@testable import HouseMate

final class MaintenanceItemTests: XCTestCase {
    func test_status_isRed_whenNeverCompleted() {
        let item = MaintenanceItem.makeTest(lastCompletedDate: nil)
        XCTAssertEqual(item.status, .red)
    }

    func test_status_isGreen_whenDueFarAway() {
        let lastDone = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let item = MaintenanceItem.makeTest(intervalDays: 31, lastCompletedDate: lastDone)
        // nextDue = lastDone + 31 days = 30 days from now → green
        XCTAssertEqual(item.status, .green)
    }

    func test_status_isYellow_whenDueSoon() {
        let lastDone = Calendar.current.date(byAdding: .day, value: -80, to: Date())!
        let item = MaintenanceItem.makeTest(intervalDays: 90, lastCompletedDate: lastDone)
        // nextDue = lastDone + 90 = 10 days from now → yellow
        XCTAssertEqual(item.status, .yellow)
    }

    func test_status_isRed_whenOverdue() {
        let lastDone = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let item = MaintenanceItem.makeTest(intervalDays: 90, lastCompletedDate: lastDone)
        // nextDue = 10 days ago → red
        XCTAssertEqual(item.status, .red)
    }

    func test_status_isYellow_atExactly14DaysBoundary() {
        // daysUntil == 14 should be yellow (condition is > 14 for green)
        let lastDone = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let item = MaintenanceItem.makeTest(intervalDays: 15, lastCompletedDate: lastDone)
        // nextDue = lastDone + 15 = 14 days from now → boundary → yellow (not green)
        XCTAssertEqual(item.status, .yellow)
    }

    func test_status_isRed_atExactly_minusOneDay() {
        // daysUntil == -1 should be red
        let today = Calendar.current.startOfDay(for: Date())
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        let item = MaintenanceItem.makeTest(intervalDays: 1, lastCompletedDate: twoDaysAgo)
        // nextDue = twoDaysAgo + 1 = yesterday → daysUntil = -1 → red
        XCTAssertEqual(item.status, .red)
    }
}

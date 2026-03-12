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
}

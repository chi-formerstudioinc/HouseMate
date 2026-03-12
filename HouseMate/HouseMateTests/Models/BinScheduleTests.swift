// HouseMateTests/Models/BinScheduleTests.swift
import XCTest
@testable import HouseMate

final class BinScheduleTests: XCTestCase {
    // startingDate = Monday 2026-03-02, startingRotation = A
    let anchor = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 2))!

    func makeSchedule(startingRotation: String = "A") -> BinSchedule {
        BinSchedule(
            id: UUID(), householdId: UUID(),
            pickupDayOfWeek: 2, // Monday
            rotationA: "Recycling", rotationB: "Garbage",
            startingRotation: startingRotation,
            startingDate: anchor,
            notifyDayBefore: false, notifyMorningOf: false,
            createdAt: Date(), updatedAt: Date()
        )
    }

    func test_rotation_onStartingDate_isStartingRotation() {
        let schedule = makeSchedule()
        XCTAssertEqual(schedule.rotation(for: anchor), "Recycling") // weeksDiff = 0 → even → A
    }

    func test_rotation_oneWeekLater_isOtherRotation() {
        let schedule = makeSchedule()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: anchor)!
        XCTAssertEqual(schedule.rotation(for: nextWeek), "Garbage") // weeksDiff = 1 → odd → B
    }

    func test_rotation_twoWeeksLater_isStartingRotation() {
        let schedule = makeSchedule()
        let twoWeeks = Calendar.current.date(byAdding: .day, value: 14, to: anchor)!
        XCTAssertEqual(schedule.rotation(for: twoWeeks), "Recycling") // weeksDiff = 2 → even → A
    }
}

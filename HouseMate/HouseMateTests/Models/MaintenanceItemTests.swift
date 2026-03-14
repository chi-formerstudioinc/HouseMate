// HouseMateTests/Models/MaintenanceItemTests.swift
import XCTest
@testable import HouseMate

final class MaintenanceItemTests: XCTestCase {

    // MARK: - Recurring: isOverdue / isUpcoming / nextDueDate

    func test_nextDueDate_usesLastCompletedAt() {
        let last = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let item = MaintenanceItem.makeTest(frequency: .monthly, lastCompletedAt: last)
        // nextDue = last + 30 days = 20 days from now
        let expected = Calendar.current.date(byAdding: .day, value: 30, to: last)!
        XCTAssertEqual(item.nextDueDate?.timeIntervalSince1970 ?? 0,
                       expected.timeIntervalSince1970, accuracy: 1)
    }

    func test_nextDueDate_usesStartDate_whenNoLastCompleted() {
        let start = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let item = MaintenanceItem.makeTest(frequency: .weekly, lastCompletedAt: nil, startDate: start)
        let expected = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        XCTAssertEqual(item.nextDueDate?.timeIntervalSince1970 ?? 0,
                       expected.timeIntervalSince1970, accuracy: 1)
    }

    func test_isOverdue_whenNextDueIsInPast() {
        let last = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let item = MaintenanceItem.makeTest(frequency: .quarterly, lastCompletedAt: last)
        // nextDue = last + 91 = ~9 days ago → overdue
        XCTAssertTrue(item.isOverdue)
        XCTAssertFalse(item.isUpcoming)
    }

    func test_isUpcoming_whenNextDueIsWithin30Days() {
        let last = Calendar.current.date(byAdding: .day, value: -80, to: Date())!
        let item = MaintenanceItem.makeTest(frequency: .quarterly, lastCompletedAt: last)
        // nextDue = last + 91 = ~11 days from now → upcoming
        XCTAssertFalse(item.isOverdue)
        XCTAssertTrue(item.isUpcoming)
    }

    func test_notOverdueNotUpcoming_whenNextDueFarOut() {
        let last = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let item = MaintenanceItem.makeTest(frequency: .annual, lastCompletedAt: last)
        // nextDue = last + 365 = ~355 days from now
        XCTAssertFalse(item.isOverdue)
        XCTAssertFalse(item.isUpcoming)
    }

    func test_nextDueDate_isNil_forRepairItem() {
        let item = MaintenanceItem(
            id: UUID(), householdId: UUID(),
            itemType: .repair, title: "Fix faucet", category: .plumbing,
            notes: nil, assignedTo: nil,
            createdAt: Date(), updatedAt: Date(),
            frequency: nil, startDate: nil, lastCompletedAt: nil,
            requiresScheduling: false, scheduledDate: nil, contractor: nil,
            repairStatus: .open, description: nil,
            estimatedCost: nil, actualCost: nil,
            installedDate: nil, expectedLifeYears: nil, brand: nil, model: nil
        )
        XCTAssertNil(item.nextDueDate)
        XCTAssertFalse(item.isOverdue)
    }

    // MARK: - Lifecycle: ageProgress / ageStatus

    func test_ageStatus_isGood_whenNewAppliance() {
        let installed = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let item = MaintenanceItem.makeLifecycleTest(
            installedDate: installed, expectedLifeYears: 15)
        XCTAssertEqual(item.ageStatus, .good)
    }

    func test_ageStatus_isWatch_whenApproachingEnd() {
        let installed = Calendar.current.date(byAdding: .year, value: -13, to: Date())!
        let item = MaintenanceItem.makeLifecycleTest(
            installedDate: installed, expectedLifeYears: 15)
        // ~87% used → watch (0.7–0.9)
        XCTAssertEqual(item.ageStatus, .watch)
    }

    func test_ageStatus_isReplaceSoon_whenAtEnd() {
        let installed = Calendar.current.date(byAdding: .year, value: -14, to: Date())!
        let item = MaintenanceItem.makeLifecycleTest(
            installedDate: installed, expectedLifeYears: 15)
        // ~93% used → replaceSoon (≥0.9)
        XCTAssertEqual(item.ageStatus, .replaceSoon)
    }

    func test_ageProgress_capsAt1_whenOverExpectedLife() {
        let installed = Calendar.current.date(byAdding: .year, value: -20, to: Date())!
        let item = MaintenanceItem.makeLifecycleTest(
            installedDate: installed, expectedLifeYears: 10)
        XCTAssertEqual(item.ageProgress, 1.0)
    }

    func test_ageStatus_isNil_forRecurringItem() {
        let item = MaintenanceItem.makeTest()
        XCTAssertNil(item.ageStatus)
        XCTAssertNil(item.ageProgress)
    }
}

// HouseMateTests/Services/TaskServiceTests.swift
import XCTest
@testable import HouseMate

final class TaskServiceTests: XCTestCase {
    // Unit-test the recurring advancement logic (pure function, no network)
    func test_advancedTask_resetsCompletionFields() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        var task = HMTask.makeTest(dueDate: base, isRecurring: true, recurringInterval: .weekly,
                                   isCompleted: true, completedBy: UUID(), completedAt: Date())
        TaskService.applyRecurringAdvancement(to: &task)
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedBy)
        XCTAssertNil(task.completedAt)
    }

    func test_advancedTask_advancesDueDateByWeek() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        var task = HMTask.makeTest(dueDate: base, isRecurring: true, recurringInterval: .weekly)
        TaskService.applyRecurringAdvancement(to: &task)
        let expected = Calendar.current.date(byAdding: .day, value: 7, to: base)!
        XCTAssertEqual(task.dueDate, expected)
    }

    func test_advancedTask_setsNilDueDateToTodayPlusInterval() {
        var task = HMTask.makeTest(dueDate: nil, isRecurring: true, recurringInterval: .daily)
        TaskService.applyRecurringAdvancement(to: &task)
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        XCTAssertEqual(task.dueDate, expected)
    }
}

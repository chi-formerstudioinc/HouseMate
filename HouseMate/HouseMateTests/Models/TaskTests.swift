// HouseMateTests/Models/TaskTests.swift
import XCTest
@testable import HouseMate

final class TaskTests: XCTestCase {
    func test_task_decodesFromJSON() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "household_id": "00000000-0000-0000-0000-000000000002",
          "title": "Take out trash",
          "category": "other",
          "priority": "medium",
          "assigned_to": null,
          "due_date": "2026-03-15",
          "is_recurring": true,
          "recurring_interval": "weekly",
          "is_completed": false,
          "completed_by": null,
          "completed_at": null,
          "template_id": null,
          "created_at": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let task = try HouseMateDecoder.decode(HMTask.self, from: json)
        XCTAssertEqual(task.title, "Take out trash")
        XCTAssertEqual(task.recurringInterval, .weekly)
        XCTAssertFalse(task.isCompleted)
    }

    func test_task_nextDueDate_weekly() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let task = HMTask.makeTest(dueDate: base, isRecurring: true, recurringInterval: .weekly)
        XCTAssertEqual(task.nextDueDate, Calendar.current.date(byAdding: .day, value: 7, to: base))
    }

    func test_task_nextDueDate_monthly() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let task = HMTask.makeTest(dueDate: base, isRecurring: true, recurringInterval: .monthly)
        XCTAssertEqual(task.nextDueDate, Calendar.current.date(byAdding: .month, value: 1, to: base))
    }

    func test_task_isOverdue_whenDueDatePast() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = HMTask.makeTest(dueDate: yesterday, isCompleted: false)
        XCTAssertTrue(task.isOverdue)
    }

    func test_task_isNotOverdue_whenCompleted() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = HMTask.makeTest(dueDate: yesterday, isCompleted: true)
        XCTAssertFalse(task.isOverdue)
    }

    func test_task_isNotOverdue_whenDueToday() {
        let today = Calendar.current.startOfDay(for: Date())
        let task = HMTask.makeTest(dueDate: today, isCompleted: false)
        XCTAssertFalse(task.isOverdue)
    }

    func test_task_nextDueDate_daily() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let task = HMTask.makeTest(dueDate: base, isRecurring: true, recurringInterval: .daily)
        XCTAssertEqual(task.nextDueDate, Calendar.current.date(byAdding: .day, value: 1, to: base))
    }

    func test_task_nextDueDate_nilWhenNotRecurring() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let task = HMTask.makeTest(dueDate: base, isRecurring: false, recurringInterval: .weekly)
        XCTAssertNil(task.nextDueDate)
    }

    func test_taskCompletionLog_decodesFromJSON() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "task_id": "00000000-0000-0000-0000-000000000002",
          "completed_by": "00000000-0000-0000-0000-000000000003",
          "completed_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let log = try HouseMateDecoder.decode(TaskCompletionLog.self, from: json)
        XCTAssertEqual(log.taskId, UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        XCTAssertEqual(log.completedBy, UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
        XCTAssertNotNil(log.completedAt)
    }
}

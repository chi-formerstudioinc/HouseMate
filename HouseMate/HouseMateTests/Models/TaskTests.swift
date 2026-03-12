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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = ISO8601DateFormatter().date(from: s) { return date }
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            if let date = df.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad date: \(s)"))
        }
        let task = try decoder.decode(HMTask.self, from: json)
        XCTAssertEqual(task.title, "Take out trash")
        XCTAssertEqual(task.recurringInterval, .weekly)
        XCTAssertFalse(task.isCompleted)
    }

    func test_task_nextDueDate_weekly() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let task = HMTask.makeTest(dueDate: base, recurringInterval: .weekly)
        XCTAssertEqual(task.nextDueDate, Calendar.current.date(byAdding: .day, value: 7, to: base))
    }

    func test_task_nextDueDate_monthly() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let task = HMTask.makeTest(dueDate: base, recurringInterval: .monthly)
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
}

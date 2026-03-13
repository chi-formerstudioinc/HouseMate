// HouseMateTests/Helpers/HMTask+makeTest.swift
import Foundation
@testable import HouseMate

extension HMTask {
    static func makeTest(
        id: UUID = UUID(),
        householdId: UUID = UUID(),
        title: String = "Test Task",
        category: TaskCategory = .other,
        priority: TaskPriority = .medium,
        assignedTo: UUID? = nil,
        dueDate: Date? = nil,
        isRecurring: Bool = false,
        recurringInterval: RecurringInterval? = nil,
        isCompleted: Bool = false,
        completedBy: UUID? = nil,
        completedAt: Date? = nil,
        templateId: UUID? = nil
    ) -> HMTask {
        HMTask(
            id: id, householdId: householdId, title: title,
            category: category, priority: priority, assignedTo: assignedTo,
            dueDate: dueDate, isRecurring: isRecurring, recurringInterval: recurringInterval,
            isCompleted: isCompleted, completedBy: completedBy, completedAt: completedAt,
            templateId: templateId, createdAt: Date(), updatedAt: Date()
        )
    }
}

// HouseMate/Models/Task.swift
import Foundation

// Named HMTask to avoid conflict with Swift concurrency's Task type
struct HMTask: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    var title: String
    var category: TaskCategory
    var priority: TaskPriority
    var assignedTo: UUID?
    var dueDate: Date?
    var isRecurring: Bool
    var recurringInterval: RecurringInterval?
    var isCompleted: Bool
    var completedBy: UUID?
    var completedAt: Date?
    let templateId: UUID?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, category, priority
        case householdId = "household_id"
        case assignedTo = "assigned_to"
        case dueDate = "due_date"
        case isRecurring = "is_recurring"
        case recurringInterval = "recurring_interval"
        case isCompleted = "is_completed"
        case completedBy = "completed_by"
        case completedAt = "completed_at"
        case templateId = "template_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isOverdue: Bool {
        guard !isCompleted, let due = dueDate else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    var nextDueDate: Date? {
        guard let due = dueDate, let interval = recurringInterval else { return nil }
        switch interval {
        case .daily:   return Calendar.current.date(byAdding: .day, value: 1, to: due)
        case .weekly:  return Calendar.current.date(byAdding: .day, value: 7, to: due)
        case .monthly: return Calendar.current.date(byAdding: .month, value: 1, to: due)
        }
    }
}

enum TaskCategory: String, Codable, CaseIterable {
    case kitchen, bathroom, outdoor, errands, other
    var displayName: String { rawValue.capitalized }
}

enum TaskPriority: String, Codable, CaseIterable {
    case high, medium, low
    var displayName: String { rawValue.capitalized }
}

enum RecurringInterval: String, Codable, CaseIterable {
    case daily, weekly, monthly
    var displayName: String { rawValue.capitalized }
    var days: Int {
        switch self { case .daily: return 1; case .weekly: return 7; case .monthly: return 30 }
    }
}

// Test helper
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

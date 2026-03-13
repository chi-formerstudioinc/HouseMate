// HouseMate/Models/TaskTemplate.swift
import Foundation

struct TaskTemplate: Codable, Identifiable {
    let id: UUID
    let householdId: UUID?  // nil for built-in (local only)
    let title: String
    let category: TaskCategory
    let recurringInterval: RecurringInterval?
    let isBuiltIn: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, category
        case householdId = "household_id"
        case recurringInterval = "recurring_interval"
        case isBuiltIn = "is_built_in"
    }

    // Convenience init for built-in templates (local, no DB row)
    init(builtInTitle: String, category: TaskCategory, recurringInterval: RecurringInterval?) {
        self.id = UUID()
        self.householdId = nil
        self.title = builtInTitle
        self.category = category
        self.recurringInterval = recurringInterval
        self.isBuiltIn = true
    }

    // Init for DB rows
    init(id: UUID, householdId: UUID, title: String, category: TaskCategory,
         recurringInterval: RecurringInterval?) {
        self.id = id
        self.householdId = householdId
        self.title = title
        self.category = category
        self.recurringInterval = recurringInterval
        self.isBuiltIn = false
    }
}

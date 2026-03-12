// HouseMate/Models/MaintenanceTemplate.swift
import Foundation

struct MaintenanceTemplate: Codable, Identifiable {
    let id: UUID
    let householdId: UUID?  // nil for built-in
    let name: String
    let category: MaintenanceCategory
    let intervalDays: Int
    let isBuiltIn: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case householdId = "household_id"
        case intervalDays = "interval_days"
        case isBuiltIn = "is_built_in"
    }

    init(builtInName: String, category: MaintenanceCategory, intervalDays: Int) {
        self.id = UUID()
        self.householdId = nil
        self.name = builtInName
        self.category = category
        self.intervalDays = intervalDays
        self.isBuiltIn = true
    }

    init(id: UUID, householdId: UUID, name: String, category: MaintenanceCategory,
         intervalDays: Int) {
        self.id = id
        self.householdId = householdId
        self.name = name
        self.category = category
        self.intervalDays = intervalDays
        self.isBuiltIn = false
    }
}

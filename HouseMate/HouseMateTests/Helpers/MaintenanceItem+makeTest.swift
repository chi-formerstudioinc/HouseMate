// HouseMateTests/Helpers/MaintenanceItem+makeTest.swift
import Foundation
@testable import HouseMate

extension MaintenanceItem {
    static func makeTest(
        id: UUID = UUID(),
        householdId: UUID = UUID(),
        name: String = "Test Item",
        category: MaintenanceCategory = .yearRound,
        intervalDays: Int = 90,
        lastCompletedDate: Date? = nil
    ) -> MaintenanceItem {
        MaintenanceItem(
            id: id, householdId: householdId, name: name,
            category: category, intervalDays: intervalDays,
            lastCompletedDate: lastCompletedDate, notes: nil, templateId: nil,
            createdAt: Date(), updatedAt: Date()
        )
    }
}

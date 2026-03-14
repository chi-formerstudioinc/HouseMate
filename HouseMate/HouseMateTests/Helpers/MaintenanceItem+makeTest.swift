// HouseMateTests/Helpers/MaintenanceItem+makeTest.swift
import Foundation
@testable import HouseMate

extension MaintenanceItem {
    /// Creates a recurring MaintenanceItem for use in unit tests.
    static func makeTest(
        id: UUID = UUID(),
        householdId: UUID = UUID(),
        title: String = "Test Item",
        category: MaintenanceCategory = .exterior,
        frequency: MaintenanceFrequency = .quarterly,
        lastCompletedAt: Date? = nil,
        startDate: Date? = nil
    ) -> MaintenanceItem {
        MaintenanceItem(
            id: id,
            householdId: householdId,
            itemType: .recurring,
            title: title,
            category: category,
            notes: nil,
            assignedTo: nil,
            createdAt: Date(),
            updatedAt: Date(),
            frequency: frequency,
            startDate: startDate,
            lastCompletedAt: lastCompletedAt,
            requiresScheduling: false,
            scheduledDate: nil,
            contractor: nil,
            repairStatus: nil,
            description: nil,
            estimatedCost: nil,
            actualCost: nil,
            installedDate: nil,
            expectedLifeYears: nil,
            brand: nil,
            model: nil
        )
    }

    /// Creates a lifecycle MaintenanceItem for use in unit tests.
    static func makeLifecycleTest(
        id: UUID = UUID(),
        householdId: UUID = UUID(),
        title: String = "Test Appliance",
        category: MaintenanceCategory = .hvac,
        installedDate: Date,
        expectedLifeYears: Int
    ) -> MaintenanceItem {
        MaintenanceItem(
            id: id,
            householdId: householdId,
            itemType: .lifecycle,
            title: title,
            category: category,
            notes: nil,
            assignedTo: nil,
            createdAt: Date(),
            updatedAt: Date(),
            frequency: nil,
            startDate: nil,
            lastCompletedAt: nil,
            requiresScheduling: false,
            scheduledDate: nil,
            contractor: nil,
            repairStatus: nil,
            description: nil,
            estimatedCost: nil,
            actualCost: nil,
            installedDate: installedDate,
            expectedLifeYears: expectedLifeYears,
            brand: nil,
            model: nil
        )
    }
}

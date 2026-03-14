// HouseMate/Resources/BuiltInTemplates.swift
import Foundation

enum BuiltInTemplates {
    static let tasks: [TaskTemplate] = [
        // Weekly
        TaskTemplate(builtInTitle: "Take out trash", category: .other, recurringInterval: .weekly),
        TaskTemplate(builtInTitle: "Vacuum living room", category: .other, recurringInterval: .weekly),
        TaskTemplate(builtInTitle: "Clean bathrooms", category: .bathroom, recurringInterval: .weekly),
        TaskTemplate(builtInTitle: "Wipe down kitchen counters", category: .kitchen, recurringInterval: .weekly),
        TaskTemplate(builtInTitle: "Do laundry", category: .other, recurringInterval: .weekly),
        TaskTemplate(builtInTitle: "Mop floors", category: .other, recurringInterval: .weekly),
        // Monthly
        TaskTemplate(builtInTitle: "Clean fridge", category: .kitchen, recurringInterval: .monthly),
        TaskTemplate(builtInTitle: "Dust ceiling fans", category: .other, recurringInterval: .monthly),
        TaskTemplate(builtInTitle: "Wash windows", category: .outdoor, recurringInterval: .monthly),
        TaskTemplate(builtInTitle: "Deep clean oven", category: .kitchen, recurringInterval: .monthly),
        // One-time checklists
        TaskTemplate(builtInTitle: "Spring cleaning", category: .other, recurringInterval: nil),
        TaskTemplate(builtInTitle: "Pre-guest prep", category: .other, recurringInterval: nil),
        TaskTemplate(builtInTitle: "Move-in checklist", category: .other, recurringInterval: nil),
    ]

    static let maintenance: [MaintenanceTemplate] = [
        MaintenanceTemplate(builtInName: "Change furnace filter", category: .hvac, intervalDays: 90),
        MaintenanceTemplate(builtInName: "Replace HVAC filter", category: .hvac, intervalDays: 90),
        MaintenanceTemplate(builtInName: "Clean dryer vent", category: .hvac, intervalDays: 365),
        MaintenanceTemplate(builtInName: "Sweep/blow out garage", category: .structural, intervalDays: 30),
        MaintenanceTemplate(builtInName: "Test smoke detectors", category: .electrical, intervalDays: 180),
        MaintenanceTemplate(builtInName: "Clean range hood filter", category: .hvac, intervalDays: 90),
        MaintenanceTemplate(builtInName: "Flush water heater", category: .plumbing, intervalDays: 365),
        MaintenanceTemplate(builtInName: "Check window/door seals", category: .exterior, intervalDays: 365),
        MaintenanceTemplate(builtInName: "Clean gutters", category: .exterior, intervalDays: 180),
        MaintenanceTemplate(builtInName: "Winterize outdoor faucets", category: .plumbing, intervalDays: 365),
    ]
}

// HouseMate/Services/TemplateService.swift
import Supabase
import Foundation

@MainActor
final class TemplateService {

    // MARK: - Task Templates

    func fetchUserTaskTemplates(householdId: UUID) async throws -> [TaskTemplate] {
        let rows: [TaskTemplateRow] = try await supabase
            .from("task_templates")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .order("title", ascending: true)
            .execute()
            .value
        return rows.map { row in
            TaskTemplate(
                id: row.id,
                householdId: row.household_id,
                title: row.title,
                category: row.category,
                recurringInterval: row.recurring_interval
            )
        }
    }

    func createTaskTemplate(householdId: UUID, title: String, category: TaskCategory,
                            recurringInterval: RecurringInterval?) async throws -> TaskTemplate {
        let insert = TaskTemplateInsert(
            household_id: householdId,
            title: title,
            category: category.rawValue,
            recurring_interval: recurringInterval?.rawValue
        )
        let row: TaskTemplateRow = try await supabase
            .from("task_templates")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
        return TaskTemplate(
            id: row.id,
            householdId: row.household_id,
            title: row.title,
            category: row.category,
            recurringInterval: row.recurring_interval
        )
    }

    func deleteTaskTemplate(id: UUID) async throws {
        try await supabase
            .from("task_templates")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Maintenance Templates

    func fetchUserMaintenanceTemplates(householdId: UUID) async throws -> [MaintenanceTemplate] {
        let rows: [MaintenanceTemplateRow] = try await supabase
            .from("maintenance_templates")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .order("name", ascending: true)
            .execute()
            .value
        return rows.map { row in
            MaintenanceTemplate(
                id: row.id,
                householdId: row.household_id,
                name: row.name,
                category: row.category,
                intervalDays: row.interval_days
            )
        }
    }

    func createMaintenanceTemplate(householdId: UUID, name: String, category: MaintenanceCategory,
                                   intervalDays: Int) async throws -> MaintenanceTemplate {
        let insert = MaintenanceTemplateInsert(
            household_id: householdId,
            name: name,
            category: category.rawValue,
            interval_days: intervalDays
        )
        let row: MaintenanceTemplateRow = try await supabase
            .from("maintenance_templates")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
        return MaintenanceTemplate(
            id: row.id,
            householdId: row.household_id,
            name: row.name,
            category: row.category,
            intervalDays: row.interval_days
        )
    }

    func deleteMaintenanceTemplate(id: UUID) async throws {
        try await supabase
            .from("maintenance_templates")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// MARK: - Private DB Row Types

private struct TaskTemplateRow: Decodable {
    let id: UUID
    let household_id: UUID
    let title: String
    let category: TaskCategory
    let recurring_interval: RecurringInterval?
}

private struct TaskTemplateInsert: Encodable {
    let household_id: UUID
    let title: String
    let category: String
    let recurring_interval: String?
}

private struct MaintenanceTemplateRow: Decodable {
    let id: UUID
    let household_id: UUID
    let name: String
    let category: MaintenanceCategory
    let interval_days: Int
}

private struct MaintenanceTemplateInsert: Encodable {
    let household_id: UUID
    let name: String
    let category: String
    let interval_days: Int
}

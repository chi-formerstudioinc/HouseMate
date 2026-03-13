// HouseMate/Services/MaintenanceService.swift
import Supabase
import Foundation

@MainActor
final class MaintenanceService {
    func fetchItems(householdId: UUID) async throws -> [MaintenanceItem] {
        try await supabase
            .from("maintenance_items")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .order("name", ascending: true)
            .execute()
            .value
    }

    func createItem(_ item: MaintenanceItem) async throws -> MaintenanceItem {
        try await supabase
            .from("maintenance_items")
            .insert(item)
            .select()
            .single()
            .execute()
            .value
    }

    func updateItem(_ item: MaintenanceItem) async throws {
        try await supabase
            .from("maintenance_items")
            .update(item)
            .eq("id", value: item.id.uuidString)
            .execute()
    }

    func deleteItem(id: UUID) async throws {
        try await supabase
            .from("maintenance_items")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Logs a completion and updates the item's lastCompletedDate.
    /// Note: these two writes are not atomic. If updateItem throws, the log row will have been
    /// committed. Callers should check for an existing log on the same date before retrying.
    func logCompletion(_ log: MaintenanceLog, updatingItem item: MaintenanceItem) async throws -> MaintenanceItem {
        // Insert log
        try await supabase.from("maintenance_logs").insert(log).execute()
        // Update item's lastCompletedDate
        var updated = item
        updated.lastCompletedDate = log.completedDate
        try await updateItem(updated)
        return updated
    }

    func fetchLogs(itemId: UUID) async throws -> [MaintenanceLog] {
        try await supabase
            .from("maintenance_logs")
            .select()
            .eq("maintenance_item_id", value: itemId.uuidString)
            .order("completed_date", ascending: false)
            .execute()
            .value
    }

    func deleteLog(id: UUID) async throws {
        try await supabase
            .from("maintenance_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// HouseMate/Services/MaintenanceService.swift
import Foundation

// NOTE: This service is stubbed pending the real Supabase schema migration for the new
// MaintenanceItem model (itemType, title, category, etc.). The UI shell uses MockMaintenanceData.

@MainActor
final class MaintenanceService {
    func fetchItems(householdId: UUID) async throws -> [MaintenanceItem] {
        return []
    }

    func createItem(_ item: MaintenanceItem) async throws -> MaintenanceItem {
        return item
    }

    func updateItem(_ item: MaintenanceItem) async throws {
        // stub
    }

    func deleteItem(id: UUID) async throws {
        // stub
    }

    func logCompletion(_ log: MaintenanceCompletionLog, updatingItem item: MaintenanceItem) async throws -> MaintenanceItem {
        return item
    }

    func fetchLogs(itemId: UUID) async throws -> [MaintenanceCompletionLog] {
        return []
    }

    func deleteLog(id: UUID) async throws {
        // stub
    }
}

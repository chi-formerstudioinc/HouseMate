// HouseMate/Models/MaintenanceLog.swift
import Foundation

struct MaintenanceLog: Codable, Identifiable {
    let id: UUID
    let maintenanceItemId: UUID
    var completedDate: Date
    var notes: String?
    var cost: Decimal?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, notes, cost
        case maintenanceItemId = "maintenance_item_id"
        case completedDate = "completed_date"
        case createdAt = "created_at"
    }
}

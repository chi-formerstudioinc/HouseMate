// HouseMate/Models/MaintenanceItem.swift
import Foundation

struct MaintenanceItem: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    var name: String
    var category: MaintenanceCategory
    var intervalDays: Int
    var lastCompletedDate: Date?
    var notes: String?
    let templateId: UUID?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, category, notes
        case householdId = "household_id"
        case intervalDays = "interval_days"
        case lastCompletedDate = "last_completed_date"
        case templateId = "template_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var nextDueDate: Date? {
        guard let last = lastCompletedDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: intervalDays, to: last)
    }

    var status: MaintenanceStatus {
        guard let next = nextDueDate else { return .red }
        let today = Calendar.current.startOfDay(for: Date())
        let daysUntil = Calendar.current.dateComponents([.day], from: today, to: next).day ?? 0
        if daysUntil > 14 { return .green }
        if daysUntil >= 0 { return .yellow }
        return .red
    }
}

enum MaintenanceCategory: String, Codable, CaseIterable {
    case spring, summer, fall, winter
    case yearRound = "year_round"
    var displayName: String {
        switch self {
        case .yearRound: return "Year-Round"
        default: return rawValue.capitalized
        }
    }
}

enum MaintenanceStatus: Equatable { case green, yellow, red }

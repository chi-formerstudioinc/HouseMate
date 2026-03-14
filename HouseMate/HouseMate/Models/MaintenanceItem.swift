// HouseMate/Models/MaintenanceItem.swift
import Foundation

// MARK: - Enums

enum MaintenanceItemType: String, Codable, CaseIterable {
    case repair, recurring, lifecycle
    var displayName: String { rawValue.capitalized }
}

enum MaintenanceCategory: String, Codable, CaseIterable {
    case exterior, hvac, electrical, plumbing, structural, vehicle

    var displayName: String {
        switch self {
        case .hvac: return "HVAC"
        default: return rawValue.capitalized
        }
    }

    var iconName: String {
        switch self {
        case .exterior: return "house.fill"
        case .hvac: return "wind"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .structural: return "building.2.fill"
        case .vehicle: return "car.fill"
        }
    }
}

enum MaintenanceFrequency: String, Codable, CaseIterable {
    case weekly, monthly, quarterly, biAnnual, annual

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .biAnnual: return "Bi-Annual"
        case .annual: return "Annual"
        }
    }

    var days: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 91
        case .biAnnual: return 182
        case .annual: return 365
        }
    }
}

enum RepairStatus: String, Codable, CaseIterable {
    case open, scheduled, completed
    var displayName: String { rawValue.capitalized }
}

enum MaintenanceAgeStatus {
    case good, watch, replaceSoon
    var displayName: String {
        switch self {
        case .good: return "Good"
        case .watch: return "Watch"
        case .replaceSoon: return "Replace Soon"
        }
    }
    var color: String {
        switch self {
        case .good: return "green"
        case .watch: return "yellow"
        case .replaceSoon: return "red"
        }
    }
}

// MARK: - Model

struct MaintenanceItem: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    var itemType: MaintenanceItemType
    var title: String
    var category: MaintenanceCategory
    var notes: String?
    var assignedTo: UUID?         // repair + recurring only
    let createdAt: Date
    var updatedAt: Date

    // Recurring fields
    var frequency: MaintenanceFrequency?
    var startDate: Date?
    var lastCompletedAt: Date?
    var requiresScheduling: Bool
    var scheduledDate: Date?
    var contractor: String?

    // Repair fields
    var repairStatus: RepairStatus?
    var description: String?
    var estimatedCost: Decimal?
    var actualCost: Decimal?

    // Lifecycle fields
    var installedDate: Date?
    var expectedLifeYears: Int?
    var brand: String?
    var model: String?

    enum CodingKeys: String, CodingKey {
        case id, title, category, notes, contractor, brand, model, description
        case householdId = "household_id"
        case itemType = "item_type"
        case assignedTo = "assigned_to"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case frequency, startDate = "start_date"
        case lastCompletedAt = "last_completed_at"
        case requiresScheduling = "requires_scheduling"
        case scheduledDate = "scheduled_date"
        case repairStatus = "repair_status"
        case estimatedCost = "estimated_cost"
        case actualCost = "actual_cost"
        case installedDate = "installed_date"
        case expectedLifeYears = "expected_life_years"
    }

    // MARK: - Computed (Recurring)

    var nextDueDate: Date? {
        guard itemType == .recurring, let freq = frequency else { return nil }
        let base = lastCompletedAt ?? startDate ?? createdAt
        return Calendar.current.date(byAdding: .day, value: freq.days, to: base)
    }

    var isOverdue: Bool {
        guard itemType == .recurring, let next = nextDueDate else { return false }
        return next < Calendar.current.startOfDay(for: Date())
    }

    var isUpcoming: Bool {
        guard itemType == .recurring, let next = nextDueDate else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let in30 = Calendar.current.date(byAdding: .day, value: 30, to: today)!
        return next >= today && next <= in30
    }

    // MARK: - Computed (Lifecycle)

    var yearsOld: Double? {
        guard itemType == .lifecycle, let installed = installedDate else { return nil }
        return Double(Calendar.current.dateComponents([.day], from: installed, to: Date()).day ?? 0) / 365.25
    }

    var yearsRemaining: Double? {
        guard let old = yearsOld, let expected = expectedLifeYears else { return nil }
        return Double(expected) - old
    }

    var ageProgress: Double? {
        guard let old = yearsOld, let expected = expectedLifeYears, expected > 0 else { return nil }
        return min(old / Double(expected), 1.0)
    }

    var ageStatus: MaintenanceAgeStatus? {
        guard let progress = ageProgress else { return nil }
        if progress < 0.7 { return .good }
        if progress < 0.9 { return .watch }
        return .replaceSoon
    }
}

// MARK: - Completion Log

struct MaintenanceCompletionLog: Codable, Identifiable {
    let id: UUID
    let itemId: UUID
    let completedBy: UUID
    let completedAt: Date
    var actualCost: Decimal?
    let householdId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case completedBy = "completed_by"
        case completedAt = "completed_at"
        case actualCost = "actual_cost"
        case householdId = "household_id"
    }
}

// HouseMate/Models/BinSchedule.swift
import Foundation

struct BinSchedule: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    var pickupDayOfWeek: Int  // 1 = Sunday … 7 = Saturday
    var rotationA: String
    var rotationB: String
    var startingRotation: String  // "A" or "B"
    var startingDate: Date
    var notifyDayBefore: Bool
    var notifyMorningOf: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case pickupDayOfWeek = "pickup_day_of_week"
        case rotationA = "rotation_a"
        case rotationB = "rotation_b"
        case startingRotation = "starting_rotation"
        case startingDate = "starting_date"
        case notifyDayBefore = "notify_day_before"
        case notifyMorningOf = "notify_morning_of"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Returns the rotation label (rotationA or rotationB) for the given pickup date.
    func rotation(for date: Date) -> String {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startingDate)
        let target = cal.startOfDay(for: date)
        let daysDiff = cal.dateComponents([.day], from: start, to: target).day ?? 0
        let weeksDiff = daysDiff / 7
        let isStartingRotation = weeksDiff % 2 == 0
        if startingRotation == "A" {
            return isStartingRotation ? rotationA : rotationB
        } else if startingRotation == "B" {
            return isStartingRotation ? rotationB : rotationA
        } else {
            assertionFailure("BinSchedule.startingRotation must be 'A' or 'B', got '\(startingRotation)'")
            return rotationB
        }
    }

    /// Returns the next N pickup dates from today.
    func upcomingPickups(count: Int = 8) -> [(date: Date, rotation: String)] {
        guard (1...7).contains(pickupDayOfWeek) else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var results: [(Date, String)] = []
        var candidate = today
        while results.count < count {
            if cal.component(.weekday, from: candidate) == pickupDayOfWeek {
                results.append((candidate, rotation(for: candidate)))
            }
            candidate = cal.date(byAdding: .day, value: 1, to: candidate)!
        }
        return results
    }
}

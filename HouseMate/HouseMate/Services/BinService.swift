// HouseMate/Services/BinService.swift
import Supabase
import Foundation

@MainActor
final class BinService {
    func fetchSchedule(householdId: UUID) async throws -> BinSchedule? {
        let schedules: [BinSchedule] = try await supabase
            .from("bin_schedules")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .execute()
            .value
        return schedules.first
    }

    func upsertSchedule(_ schedule: BinSchedule) async throws -> BinSchedule {
        try await supabase
            .from("bin_schedules")
            .upsert(schedule, onConflict: "household_id")
            .select()
            .single()
            .execute()
            .value
    }
}

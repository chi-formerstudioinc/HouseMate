// HouseMate/Services/TaskService.swift
import Supabase
import Foundation

@MainActor
final class TaskService {

    func fetchTasks(householdId: UUID) async throws -> [HMTask] {
        try await supabase
            .from("tasks")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createTask(_ task: HMTask) async throws -> HMTask {
        try await supabase
            .from("tasks")
            .insert(task)
            .select()
            .single()
            .execute()
            .value
    }

    func updateTask(_ task: HMTask) async throws {
        try await supabase
            .from("tasks")
            .update(task)
            .eq("id", value: task.id.uuidString)
            .execute()
    }

    func deleteTask(id: UUID) async throws {
        try await supabase
            .from("tasks")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Complete a task. For recurring tasks, creates a log entry and advances the due date.
    /// For one-time tasks, marks it completed. Returns nil if already completed (concurrent race).
    func completeTask(_ task: HMTask, memberId: UUID) async throws -> HMTask? {
        // Fetch fresh copy to detect concurrent completion
        let fresh: HMTask = try await supabase
            .from("tasks")
            .select()
            .eq("id", value: task.id.uuidString)
            .single()
            .execute()
            .value

        guard !fresh.isCompleted else { return nil }  // already completed

        // Insert completion log
        let log = TaskCompletionLog(
            id: UUID(), taskId: task.id, completedBy: memberId, completedAt: Date()
        )
        try await supabase.from("task_completion_logs").insert(log).execute()

        if fresh.isRecurring {
            var advanced = fresh
            TaskService.applyRecurringAdvancement(to: &advanced)
            try await updateTask(advanced)
            return advanced
        } else {
            var completed = fresh
            completed.isCompleted = true
            completed.completedBy = memberId
            completed.completedAt = Date()
            try await updateTask(completed)
            return completed
        }
    }

    func fetchCompletionLogs(taskId: UUID, limit: Int = 5) async throws -> [TaskCompletionLog] {
        try await supabase
            .from("task_completion_logs")
            .select()
            .eq("task_id", value: taskId.uuidString)
            .order("completed_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Pure function: advances due date and resets completion fields on a recurring task.
    nonisolated static func applyRecurringAdvancement(to task: inout HMTask) {
        let today = Calendar.current.startOfDay(for: Date())
        if let next = task.nextDueDate {
            task.dueDate = next
        } else if let interval = task.recurringInterval {
            task.dueDate = Calendar.current.date(byAdding: .day, value: interval.days, to: today)
        }
        task.isCompleted = false
        task.completedBy = nil
        task.completedAt = nil
    }
}

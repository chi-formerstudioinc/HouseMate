// HouseMate/Models/TaskCompletionLog.swift
import Foundation

struct TaskCompletionLog: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let completedBy: UUID
    let completedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case completedBy = "completed_by"
        case completedAt = "completed_at"
    }
}

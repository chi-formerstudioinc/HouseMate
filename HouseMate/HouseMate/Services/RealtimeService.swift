// HouseMate/Services/RealtimeService.swift
import Supabase
import Foundation

/// Manages Supabase Realtime subscriptions for a household.
/// Posts NotificationCenter notifications when changes arrive so ViewModels can refresh.
@MainActor
final class RealtimeService {
    enum Notification: String {
        case tasksChangedNotification       = "RealtimeTasksChanged"
        case binScheduleChangedNotification = "RealtimeBinScheduleChanged"
        case maintenanceChangedNotification = "RealtimeMaintenanceChanged"
        case membersChangedNotification     = "RealtimeMembersChanged"

        var name: Foundation.Notification.Name { .init(rawValue) }
    }

    static let tasksChangedNotification       = Notification.tasksChangedNotification
    static let binScheduleChangedNotification = Notification.binScheduleChangedNotification
    static let maintenanceChangedNotification = Notification.maintenanceChangedNotification
    static let membersChangedNotification     = Notification.membersChangedNotification

    private var channel: RealtimeChannelV2?

    func subscribe(householdId: UUID) async {
        await unsubscribe()
        let idStr = householdId.uuidString
        let ch = supabase.channel("household-\(idStr)")

        ch.onPostgresChange(AnyAction.self, schema: "public", table: "tasks",
            filter: "household_id=eq.\(idStr)") { [weak self] _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.tasksChangedNotification.name, object: nil)
            }
        }

        // No household_id filter: task_completion_logs has no household_id column (FK through task_id).
        // RLS prevents data exposure; the notification may fire for foreign households but triggers a no-op refresh.
        ch.onPostgresChange(AnyAction.self, schema: "public", table: "task_completion_logs") { [weak self] _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.tasksChangedNotification.name, object: nil)
            }
        }

        ch.onPostgresChange(AnyAction.self, schema: "public", table: "bin_schedules",
            filter: "household_id=eq.\(idStr)") { [weak self] _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.binScheduleChangedNotification.name, object: nil)
            }
        }

        ch.onPostgresChange(AnyAction.self, schema: "public", table: "maintenance_items",
            filter: "household_id=eq.\(idStr)") { [weak self] _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.maintenanceChangedNotification.name, object: nil)
            }
        }

        // No household_id filter: maintenance_logs has no household_id column (FK through maintenance_item_id).
        ch.onPostgresChange(AnyAction.self, schema: "public", table: "maintenance_logs") { [weak self] _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.maintenanceChangedNotification.name, object: nil)
            }
        }

        ch.onPostgresChange(AnyAction.self, schema: "public", table: "members",
            filter: "household_id=eq.\(idStr)") { [weak self] _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.membersChangedNotification.name, object: nil)
            }
        }

        await ch.subscribe()
        self.channel = ch
    }

    func unsubscribe() async {
        if let ch = channel {
            await supabase.removeChannel(ch)
            channel = nil
        }
    }
}

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
            filter: "household_id=eq.\(idStr)") { _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.tasksChangedNotification.name, object: nil)
            }
        }

        ch.onPostgresChange(AnyAction.self, schema: "public", table: "task_completion_logs") { _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.tasksChangedNotification.name, object: nil)
            }
        }

        ch.onPostgresChange(AnyAction.self, schema: "public", table: "bin_schedules",
            filter: "household_id=eq.\(idStr)") { _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.binScheduleChangedNotification.name, object: nil)
            }
        }

        ch.onPostgresChange(AnyAction.self, schema: "public", table: "maintenance_items",
            filter: "household_id=eq.\(idStr)") { _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.maintenanceChangedNotification.name, object: nil)
            }
        }

        ch.onPostgresChange(AnyAction.self, schema: "public", table: "maintenance_logs") { _ in
            Task { @MainActor in
                NotificationCenter.default.post(name: RealtimeService.maintenanceChangedNotification.name, object: nil)
            }
        }

        ch.onPostgresChange(AnyAction.self, schema: "public", table: "members",
            filter: "household_id=eq.\(idStr)") { _ in
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
